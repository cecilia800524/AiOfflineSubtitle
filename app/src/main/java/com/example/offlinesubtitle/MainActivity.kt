package com.example.offlinesubtitle

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.lifecycleScope
import com.example.offlinesubtitle.asr.WavFileTranscriber
import com.example.offlinesubtitle.audio.AudioInputSource
import com.example.offlinesubtitle.export.SubtitleExportFormat
import com.example.offlinesubtitle.export.SubtitleExporter
import com.example.offlinesubtitle.service.SubtitleForegroundService
import com.example.offlinesubtitle.service.SubtitleRuntimeCoordinator
import com.example.offlinesubtitle.subtitle.SubtitleStateManager
import com.example.offlinesubtitle.ui.MainScreen
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    private lateinit var stateManager: SubtitleStateManager
    private lateinit var wavFileTranscriber: WavFileTranscriber
    private lateinit var subtitleExporter: SubtitleExporter

    private var hasMicPermission by mutableStateOf(false)
    private var exportStatusMessage by mutableStateOf<String?>(null)

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { results ->
        hasMicPermission = results[Manifest.permission.RECORD_AUDIO] == true ||
            checkPermissionGranted(Manifest.permission.RECORD_AUDIO)
    }

    private val mediaProjectionLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK && result.data != null) {
            val svcIntent = Intent(this, SubtitleForegroundService::class.java).apply {
                action = SubtitleForegroundService.ACTION_START_SYSTEM_AUDIO
                putExtra(SubtitleForegroundService.EXTRA_RESULT_CODE, result.resultCode)
                putExtra(SubtitleForegroundService.EXTRA_RESULT_DATA, result.data)
            }
            ContextCompat.startForegroundService(this, svcIntent)
        }
    }

    private val overlayPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) {
        if (Settings.canDrawOverlays(this)) {
            toggleOverlayService(show = true)
        }
    }

    private val audioFilePickerLauncher = registerForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri: Uri? ->
        if (uri != null) {
            runOfflineFileTranscription(uri)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        stateManager = SubtitleRuntimeCoordinator.getOrCreateStateManager(applicationContext)
        wavFileTranscriber = WavFileTranscriber(applicationContext)
        subtitleExporter = SubtitleExporter(applicationContext)

        refreshPermissions()
        requestRequiredPermissionsIfNeeded()

        setContent {
            MaterialTheme {
                Surface {
                    val uiState by stateManager.uiState.collectAsStateWithLifecycle()

                    MainScreen(
                        uiState = uiState,
                        hasMicPermission = hasMicPermission,
                        exportStatusMessage = exportStatusMessage,
                        onRequestMicPermission = { requestRequiredPermissionsIfNeeded() },
                        onStartStopClick = {
                            if (uiState.isRunning) {
                                sendServiceAction(SubtitleForegroundService.ACTION_STOP)
                            } else {
                                startSubtitleService(uiState.inputSource)
                            }
                        },
                        onToggleOverlayClick = {
                            if (uiState.isOverlayActive) {
                                toggleOverlayService(show = false)
                            } else if (Settings.canDrawOverlays(this)) {
                                toggleOverlayService(show = true)
                            } else {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName")
                                )
                                overlayPermissionLauncher.launch(intent)
                            }
                        },
                        onImportAudioClick = {
                            audioFilePickerLauncher.launch(arrayOf("audio/*", "video/mp4"))
                        },
                        onSwitchToMockModel = {
                            stateManager.switchToEngine(
                                engine = SubtitleRuntimeCoordinator.getMockEngine(),
                                label = "Mock NPU"
                            )
                        },
                        onSwitchToLocalModel = { profile ->
                            stateManager.switchToEngine(
                                engine = SubtitleRuntimeCoordinator.getLocalEngine(applicationContext),
                                label = profile.displayName,
                                localProfile = profile
                            )
                        },
                        onUnloadModelClick = {
                            stateManager.unloadCurrentModel()
                        },
                        onSelectInputSource = { source ->
                            stateManager.setInputSource(source)
                        },
                        onSelectBackend = { backend ->
                            stateManager.setBackendMode(backend)
                        },
                        onClearClick = {
                            stateManager.clearSubtitles()
                            exportStatusMessage = null
                        },
                        onEditSegment = { segId, newText ->
                            stateManager.editSegmentText(segId, newText)
                        },
                        onExportAndSave = { format ->
                            exportSubtitles(format, shareAfter = false)
                        },
                        onExportAndShare = { format ->
                            exportSubtitles(format, shareAfter = true)
                        },
                        onLoadBuiltInTestMode = {
                            stateManager.injectBuiltInTestSegments()
                            exportStatusMessage = "已注入含重疊時間軸之測試資料，可立即測試匯出校驗"
                        }
                    )
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        refreshPermissions()
        stateManager.refreshModelDiskUsage()
    }

    private fun startSubtitleService(source: AudioInputSource) {
        when (source) {
            AudioInputSource.SYSTEM_AUDIO -> {
                val projectionManager = getSystemService(MediaProjectionManager::class.java)
                mediaProjectionLauncher.launch(projectionManager.createScreenCaptureIntent())
            }
            AudioInputSource.SIMULATED_PCM -> {
                sendServiceAction(SubtitleForegroundService.ACTION_START_SIMULATED)
            }
            AudioInputSource.MICROPHONE -> {
                sendServiceAction(SubtitleForegroundService.ACTION_START_MIC)
            }
        }
    }

    private fun toggleOverlayService(show: Boolean) {
        val action = if (show) {
            SubtitleForegroundService.ACTION_SHOW_OVERLAY
        } else {
            SubtitleForegroundService.ACTION_HIDE_OVERLAY
        }
        val intent = Intent(this, SubtitleForegroundService::class.java).apply { this.action = action }
        if (stateManager.uiState.value.isRunning) {
            startService(intent)
        } else {
            ContextCompat.startForegroundService(this, intent)
        }
    }

    private fun sendServiceAction(action: String) {
        val intent = Intent(this, SubtitleForegroundService::class.java).apply {
            this.action = action
        }
        ContextCompat.startForegroundService(this, intent)
    }

    private fun runOfflineFileTranscription(uri: Uri) {
        lifecycleScope.launch {
            val engine = stateManager.getCurrentEngine()
            stateManager.onFileTranscribeStarted(uri.lastPathSegment ?: "audio")

            val result = wavFileTranscriber.transcribeUri(
                uri = uri,
                asrEngine = engine,
                onProgress = { progress -> stateManager.onFileTranscribeProgress(progress) }
            )

            result.onSuccess { report ->
                stateManager.onFileTranscribeCompleted(report)
            }.onFailure { err ->
                stateManager.onFileTranscribeFailed(err.message ?: "未知錯誤")
            }
        }
    }

    private fun exportSubtitles(format: SubtitleExportFormat, shareAfter: Boolean) {
        lifecycleScope.launch {
            val segments = stateManager.uiState.value.segments
            val result = subtitleExporter.export(
                segments = segments,
                format = format,
                saveToDownloads = !shareAfter
            )

            result.onSuccess { res ->
                val fixHint = if (res.overlapsFixed > 0) "（已自動修正 ${res.overlapsFixed} 處重疊）" else ""
                if (shareAfter) {
                    exportStatusMessage = "已產生 ${res.fileName}$fixHint，開啟分享面板..."
                    val shareIntent = Intent(Intent.ACTION_SEND).apply {
                        type = format.mimeType
                        putExtra(Intent.EXTRA_STREAM, res.shareUri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivity(Intent.createChooser(shareIntent, "分享字幕檔案 (${format.label})"))
                } else {
                    exportStatusMessage = "已儲存至 Downloads/${res.fileName}$fixHint"
                }
            }.onFailure { err ->
                exportStatusMessage = "匯出失敗: ${err.message}"
            }
        }
    }

    private fun refreshPermissions() {
        hasMicPermission = checkPermissionGranted(Manifest.permission.RECORD_AUDIO)
    }

    private fun requestRequiredPermissionsIfNeeded() {
        val needed = buildList {
            if (!checkPermissionGranted(Manifest.permission.RECORD_AUDIO)) {
                add(Manifest.permission.RECORD_AUDIO)
            }
            if (!checkPermissionGranted(Manifest.permission.POST_NOTIFICATIONS)) {
                add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
        if (needed.isNotEmpty()) {
            permissionLauncher.launch(needed.toTypedArray())
        }
    }

    private fun checkPermissionGranted(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
    }
}
