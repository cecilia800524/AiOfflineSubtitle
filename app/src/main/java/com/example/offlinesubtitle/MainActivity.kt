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
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.offlinesubtitle.bridge.BridgeHostCallbacks
import com.example.offlinesubtitle.bridge.OfflineSubtitleViewModel
import com.example.offlinesubtitle.ui.MainScreen

class MainActivity : ComponentActivity(), BridgeHostCallbacks {

    private lateinit var subtitleViewModel: OfflineSubtitleViewModel
    private var hasMicPermission by mutableStateOf(false)

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { results ->
        hasMicPermission = results[Manifest.permission.RECORD_AUDIO] == true ||
            checkPermissionGranted(Manifest.permission.RECORD_AUDIO)
    }

    private val mediaProjectionLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        val data = result.data
        if (result.resultCode == Activity.RESULT_OK && data != null) {
            subtitleViewModel.onMediaProjectionGranted(result.resultCode, data)
        }
    }

    private val overlayPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) {
        if (Settings.canDrawOverlays(this)) {
            subtitleViewModel.onToggleOverlay()
        }
    }

    private val audioFilePickerLauncher = registerForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri: Uri? ->
        if (uri != null) {
            subtitleViewModel.onAudioUriPicked(uri)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        subtitleViewModel = ViewModelProvider(this)[OfflineSubtitleViewModel::class.java]
        subtitleViewModel.attachHost(this)

        refreshPermissions()
        requestMicAndNotificationPermissions()

        setContent {
            val vm: OfflineSubtitleViewModel = viewModel()
            val uiState by vm.uiState.collectAsStateWithLifecycle()
            val bridgeState by vm.bridgeState.collectAsStateWithLifecycle()

            MaterialTheme {
                Surface {
                    MainScreen(
                        bridge = vm.bridge,
                        uiState = uiState,
                        bridgeState = bridgeState,
                        hasMicPermission = hasMicPermission,
                        onRequestMicPermission = { requestMicAndNotificationPermissions() },
                        onStartStopClick = { vm.onStartStopClick(hasMicPermission) },
                        onToggleOverlayClick = { vm.onToggleOverlay() },
                        onImportAudioClick = { vm.onImportAudioClick() },
                        onSwitchToMockModel = { vm.onSwitchToMockModel() },
                        onSwitchToLocalModel = { profile -> vm.onSwitchToLocalModel(profile) },
                        onUnloadModelClick = { vm.onUnloadModel() },
                        onSelectInputSource = { source -> vm.onSelectInputSource(source) },
                        onSelectBackend = { backend -> vm.onSelectBackend(backend) },
                        onClearClick = { vm.onClearSubtitles() },
                        onEditSegment = { segId, newText -> vm.onEditSegment(segId, newText) },
                        onExportAndSave = { format -> vm.onExport(format, shareAfter = false) },
                        onExportAndShare = { format -> vm.onExport(format, shareAfter = true) },
                        onLoadBuiltInTestMode = { vm.onLoadBuiltInTestMode() }
                    )
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        refreshPermissions()
        subtitleViewModel.onRefreshModels()
    }

    override fun onDestroy() {
        super.onDestroy()
        subtitleViewModel.detachHost()
    }

    // --- BridgeHostCallbacks 實作 ---

    override fun requestMicAndNotificationPermissions() {
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

    override fun launchMediaProjectionConsent() {
        val projectionManager = getSystemService(MediaProjectionManager::class.java)
        mediaProjectionLauncher.launch(projectionManager.createScreenCaptureIntent())
    }

    override fun launchOverlayPermissionSettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName")
        )
        overlayPermissionLauncher.launch(intent)
    }

    override fun launchAudioFilePicker() {
        audioFilePickerLauncher.launch(arrayOf("audio/*", "video/mp4"))
    }

    override fun launchShareSheet(shareUri: Uri, mimeType: String, formatLabel: String) {
        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, shareUri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(shareIntent, "分享字幕檔案 ($formatLabel)"))
    }

    private fun refreshPermissions() {
        hasMicPermission = checkPermissionGranted(Manifest.permission.RECORD_AUDIO)
    }

    private fun checkPermissionGranted(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
    }
}
