package com.example.offlinesubtitle.bridge

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.util.Log
import android.webkit.JavascriptInterface
import android.webkit.WebView
import androidx.core.content.ContextCompat
import com.example.offlinesubtitle.asr.BackendTag
import com.example.offlinesubtitle.asr.LocalModelProfile
import com.example.offlinesubtitle.asr.LocalNpuAsrEngine
import com.example.offlinesubtitle.asr.MockNpuAsrEngine
import com.example.offlinesubtitle.asr.WavFileTranscriber
import com.example.offlinesubtitle.audio.AudioInputSource
import com.example.offlinesubtitle.export.SubtitleExportFormat
import com.example.offlinesubtitle.export.SubtitleExporter
import com.example.offlinesubtitle.service.SubtitleForegroundService
import com.example.offlinesubtitle.subtitle.SubtitleStateManager
import com.example.offlinesubtitle.subtitle.SubtitleUiState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.sample
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject

interface BridgeHostCallbacks {
    fun requestMicAndNotificationPermissions()
    fun launchMediaProjectionConsent()
    fun launchOverlayPermissionSettings()
    fun launchAudioFilePicker()
    fun launchModelFolderPicker()
    fun launchShareSheet(shareUri: Uri, mimeType: String, formatLabel: String)
}

data class BridgeControlState(
    val isHostAttached: Boolean = false,
    val isWebViewAttached: Boolean = false,
    val serviceLifecycleState: String = "IDLE",
    val lastCommand: String = "NONE",
    val exportStatusMessage: String? = null,
    val lastSerializedStateJson: String = "{}",
    val commandHistory: List<String> = emptyList()
)

class OfflineSubtitleBridge(
    private val appContext: Context,
    val stateManager: SubtitleStateManager,
    private val mockAsrEngine: MockNpuAsrEngine,
    private val localNpuAsrEngine: LocalNpuAsrEngine
) {
    companion object {
        private const val TAG_STATE = "[ASR_STATE]"
        private const val TAG_SERVICE = "[ASR_SERVICE]"
        const val JS_INTERFACE_NAME = "AndroidOfflineSubtitleBridge"
    }

    private val mainScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val wavFileTranscriber = WavFileTranscriber(appContext)
    private val subtitleExporter = SubtitleExporter(appContext)

    private var hostCallbacks: BridgeHostCallbacks? = null
    private var attachedWebView: WebView? = null
    private var statePushJob: Job? = null

    private val _bridgeState = MutableStateFlow(
        BridgeControlState(lastSerializedStateJson = serializeUiState(stateManager.uiState.value))
    )
    val bridgeState: StateFlow<BridgeControlState> = _bridgeState.asStateFlow()

    val uiState: StateFlow<SubtitleUiState>
        get() = stateManager.uiState

    init {
        startStateObserver()
    }

    fun attachHost(callbacks: BridgeHostCallbacks) {
        hostCallbacks = callbacks
        _bridgeState.update { it.copy(isHostAttached = true) }
        recordCommand("HOST_ATTACHED")
    }

    fun detachHost() {
        hostCallbacks = null
        _bridgeState.update { it.copy(isHostAttached = false) }
    }

    fun attachWebView(webView: WebView) {
        attachedWebView = webView
        _bridgeState.update { it.copy(isWebViewAttached = true) }
        pushStateToWebView(stateManager.uiState.value)
        recordCommand("WEBVIEW_ATTACHED")
    }

    fun detachWebView(webView: WebView) {
        if (attachedWebView === webView) {
            attachedWebView = null
            _bridgeState.update { it.copy(isWebViewAttached = false) }
        }
    }

    fun notifyServiceLifecycle(lifecycleEvent: String) {
        _bridgeState.update { it.copy(serviceLifecycleState = lifecycleEvent) }
        Log.d(TAG_SERVICE, "Bridge observed service lifecycle -> $lifecycleEvent")
    }

    // --- 模型路徑設定 State Handlers（同步於 MainScreen 與 WebView Bridge UI）---

    fun handlePickModelFolderClick() {
        recordCommand("PICK_MODEL_FOLDER_SAF")
        hostCallbacks?.launchModelFolderPicker()
    }

    fun handleModelFolderPicked(treeUri: Uri) {
        val uriString = treeUri.toString()
        recordCommand("SAF_FOLDER_SELECTED:$uriString")
        stateManager.applyCustomModelPath(uriString)
    }

    fun handleApplyModelPath(rawPath: String) {
        recordCommand("APPLY_MODEL_PATH:${rawPath.trim()}")
        stateManager.applyCustomModelPath(rawPath)
    }

    fun handleResetModelPath() {
        recordCommand("RESET_MODEL_PATH_DEFAULT")
        stateManager.resetModelPathToDefault()
    }

    fun handleRefreshExternalModels() {
        recordCommand("REFRESH_EXTERNAL_MODELS")
        stateManager.refreshModelDiskUsage(validateAndAlert = false)
    }

    // --- 音訊服務與 ASR 控制 State Handlers ---

    fun handleStartOrStopToggle(hasMicPermission: Boolean) {
        if (stateManager.uiState.value.isRunning) {
            handleStopService()
        } else {
            val source = stateManager.uiState.value.inputSource
            if (source == AudioInputSource.MICROPHONE && !hasMicPermission) {
                hostCallbacks?.requestMicAndNotificationPermissions()
                recordCommand("REQUEST_MIC_PERMISSION")
                return
            }
            handleStartService(source)
        }
    }

    fun handleStartService(source: AudioInputSource) {
        recordCommand("START_SERVICE:${source.name}")
        stateManager.setInputSource(source)
        when (source) {
            AudioInputSource.SYSTEM_AUDIO -> {
                hostCallbacks?.launchMediaProjectionConsent()
            }
            AudioInputSource.SIMULATED_PCM -> {
                sendServiceAction(SubtitleForegroundService.ACTION_START_SIMULATED)
            }
            AudioInputSource.MICROPHONE -> {
                sendServiceAction(SubtitleForegroundService.ACTION_START_MIC)
            }
        }
    }

    fun handleMediaProjectionGranted(resultCode: Int, resultData: Intent) {
        recordCommand("MEDIA_PROJECTION_GRANTED")
        val svcIntent = Intent(appContext, SubtitleForegroundService::class.java).apply {
            action = SubtitleForegroundService.ACTION_START_SYSTEM_AUDIO
            putExtra(SubtitleForegroundService.EXTRA_RESULT_CODE, resultCode)
            putExtra(SubtitleForegroundService.EXTRA_RESULT_DATA, resultData)
        }
        ContextCompat.startForegroundService(appContext, svcIntent)
    }

    fun handleStopService() {
        recordCommand("STOP_SERVICE")
        sendServiceAction(SubtitleForegroundService.ACTION_STOP)
    }

    fun handleToggleOverlay() {
        val currentlyActive = stateManager.uiState.value.isOverlayActive
        if (currentlyActive) {
            recordCommand("HIDE_OVERLAY")
            sendServiceAction(SubtitleForegroundService.ACTION_HIDE_OVERLAY)
            return
        }
        if (Settings.canDrawOverlays(appContext)) {
            recordCommand("SHOW_OVERLAY")
            sendServiceAction(SubtitleForegroundService.ACTION_SHOW_OVERLAY)
        } else {
            recordCommand("REQUEST_OVERLAY_PERMISSION")
            hostCallbacks?.launchOverlayPermissionSettings()
        }
    }

    fun handleSwitchToMockModel() {
        recordCommand("SWITCH_MODEL:MOCK")
        stateManager.switchToEngine(engine = mockAsrEngine, label = "Mock NPU")
    }

    fun handleSwitchToLocalModel(profile: LocalModelProfile) {
        recordCommand("SWITCH_MODEL:${profile.dirName}")
        stateManager.switchToEngine(
            engine = localNpuAsrEngine,
            label = profile.displayName,
            localProfile = profile
        )
    }

    fun handleUnloadModel() {
        recordCommand("UNLOAD_MODEL")
        stateManager.unloadCurrentModel()
    }

    fun handleSelectInputSource(source: AudioInputSource) {
        recordCommand("SET_INPUT_SOURCE:${source.name}")
        stateManager.setInputSource(source)
    }

    fun handleSelectBackend(backendTag: BackendTag) {
        recordCommand("SET_BACKEND:${backendTag.label}")
        stateManager.setBackendMode(backendTag)
    }

    fun handleImportAudioClick() {
        recordCommand("OPEN_AUDIO_PICKER")
        hostCallbacks?.launchAudioFilePicker()
    }

    fun handleAudioUriPicked(uri: Uri) {
        recordCommand("TRANSCRIBE_FILE:${uri.lastPathSegment ?: "audio"}")
        mainScope.launch {
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

    fun handleEditSegment(segmentId: Long, newText: String) {
        recordCommand("EDIT_SEGMENT:$segmentId")
        stateManager.editSegmentText(segmentId, newText)
    }

    fun handleClearSubtitles() {
        recordCommand("CLEAR_SUBTITLES")
        stateManager.clearSubtitles()
        _bridgeState.update { it.copy(exportStatusMessage = null) }
    }

    fun handleInjectBuiltInTestMode() {
        recordCommand("INJECT_TEST_SEGMENTS")
        stateManager.injectBuiltInTestSegments()
        _bridgeState.update {
            it.copy(exportStatusMessage = "已注入含重疊時間軸之測試資料，可立即測試匯出校驗")
        }
    }

    fun handleExportSubtitles(format: SubtitleExportFormat, shareAfter: Boolean) {
        recordCommand("EXPORT:${format.label}:share=$shareAfter")
        mainScope.launch {
            val segments = stateManager.uiState.value.segments
            val result = subtitleExporter.export(
                segments = segments,
                format = format,
                saveToDownloads = !shareAfter
            )

            result.onSuccess { res ->
                val fixHint = if (res.overlapsFixed > 0) "（已自動修正 ${res.overlapsFixed} 處重疊）" else ""
                if (shareAfter) {
                    _bridgeState.update {
                        it.copy(exportStatusMessage = "已產生 ${res.fileName}$fixHint，開啟分享面板...")
                    }
                    hostCallbacks?.launchShareSheet(res.shareUri, format.mimeType, format.label)
                } else {
                    _bridgeState.update {
                        it.copy(exportStatusMessage = "已儲存至 Downloads/${res.fileName}$fixHint")
                    }
                }
            }.onFailure { err ->
                _bridgeState.update { it.copy(exportStatusMessage = "匯出失敗: ${err.message}") }
            }
        }
    }

    // --- WebView @JavascriptInterface 橋接端點 ---

    @JavascriptInterface
    fun getStateJson(): String = serializeUiState(stateManager.uiState.value)

    @JavascriptInterface
    fun pickModelFolder() {
        mainScope.launch { handlePickModelFolderClick() }
    }

    @JavascriptInterface
    fun applyModelPath(path: String) {
        mainScope.launch { handleApplyModelPath(path) }
    }

    @JavascriptInterface
    fun resetModelPath() {
        mainScope.launch { handleResetModelPath() }
    }

    @JavascriptInterface
    fun startService(sourceName: String) {
        mainScope.launch {
            val source = runCatching { AudioInputSource.valueOf(sourceName) }
                .getOrDefault(AudioInputSource.MICROPHONE)
            handleStartService(source)
        }
    }

    @JavascriptInterface
    fun stopService() {
        mainScope.launch { handleStopService() }
    }

    @JavascriptInterface
    fun toggleOverlay() {
        mainScope.launch { handleToggleOverlay() }
    }

    @JavascriptInterface
    fun switchModel(mode: String) {
        mainScope.launch {
            when (mode) {
                "WHISPER_TINY" -> handleSwitchToLocalModel(LocalModelProfile.WHISPER_TINY_QNN)
                "WHISPER_SMALL" -> handleSwitchToLocalModel(LocalModelProfile.WHISPER_SMALL_QNN)
                else -> handleSwitchToMockModel()
            }
        }
    }

    @JavascriptInterface
    fun unloadModel() {
        mainScope.launch { handleUnloadModel() }
    }

    @JavascriptInterface
    fun setBackendMode(backendName: String) {
        mainScope.launch {
            val tag = runCatching { BackendTag.valueOf(backendName) }
                .getOrDefault(BackendTag.QNN_NPU)
            handleSelectBackend(tag)
        }
    }

    @JavascriptInterface
    fun setInputSource(sourceName: String) {
        mainScope.launch {
            val source = runCatching { AudioInputSource.valueOf(sourceName) }
                .getOrDefault(AudioInputSource.MICROPHONE)
            handleSelectInputSource(source)
        }
    }

    @JavascriptInterface
    fun importAudioFile() {
        mainScope.launch { handleImportAudioClick() }
    }

    @JavascriptInterface
    fun clearSubtitles() {
        mainScope.launch { handleClearSubtitles() }
    }

    @JavascriptInterface
    fun injectTestSegments() {
        mainScope.launch { handleInjectBuiltInTestMode() }
    }

    @JavascriptInterface
    fun exportSubtitles(formatName: String, shareAfter: Boolean) {
        mainScope.launch {
            val fmt = runCatching { SubtitleExportFormat.valueOf(formatName) }
                .getOrDefault(SubtitleExportFormat.SRT)
            handleExportSubtitles(fmt, shareAfter)
        }
    }

    private fun startStateObserver() {
        statePushJob?.cancel()
        statePushJob = mainScope.launch {
            @Suppress("OPT_IN_USAGE")
            stateManager.uiState
                .sample(100L)
                .collect { state ->
                    val json = serializeUiState(state)
                    _bridgeState.update { it.copy(lastSerializedStateJson = json) }
                    pushStateToWebView(state, json)
                }
        }
    }

    private fun pushStateToWebView(state: SubtitleUiState, precomputedJson: String? = null) {
        val webView = attachedWebView ?: return
        val json = precomputedJson ?: serializeUiState(state)
        val quoted = JSONObject.quote(json)
        webView.post {
            webView.evaluateJavascript(
                "window.__onNativeSubtitleState && window.__onNativeSubtitleState($quoted);",
                null
            )
        }
    }

    private fun sendServiceAction(action: String) {
        val intent = Intent(appContext, SubtitleForegroundService::class.java).apply {
            this.action = action
        }
        if (stateManager.uiState.value.isRunning || action == SubtitleForegroundService.ACTION_STOP) {
            appContext.startService(intent)
        } else {
            ContextCompat.startForegroundService(appContext, intent)
        }
    }

    private fun recordCommand(cmd: String) {
        Log.d(TAG_STATE, "Bridge command -> $cmd")
        _bridgeState.update { state ->
            val updated = (listOf(cmd) + state.commandHistory).take(12)
            state.copy(lastCommand = cmd, commandHistory = updated)
        }
    }

    private fun serializeUiState(state: SubtitleUiState): String {
        val segArray = JSONArray()
        state.segments.forEach { seg ->
            segArray.put(
                JSONObject().apply {
                    put("id", seg.id)
                    put("text", seg.text)
                    put("isFinal", seg.isFinal)
                    put("startTimeMs", seg.startTimeMs)
                    put("endTimeMs", seg.endTimeMs)
                    put("backendTag", seg.backendTag.label)
                    put("latencyMs", seg.latencyMs)
                }
            )
        }

        return JSONObject().apply {
            put("isRunning", state.isRunning)
            put("isFileTranscribing", state.isFileTranscribing)
            put("fileTranscribeProgress", state.fileTranscribeProgress.toDouble())
            put("inputSource", state.inputSource.name)
            put("backendTag", state.backendTag.label)
            put("activeEngineLabel", state.activeEngineLabel)
            put("currentModelPath", state.currentModelPath)
            put("isCustomModelPath", state.isCustomModelPath)
            put("modelPathError", state.modelPathError ?: "")
            put("modelPathAlertEventId", state.modelPathAlertEventId)
            put("isModelLoaded", state.isModelLoaded)
            put("modelsDiskSizeMb", state.modelsDiskSizeMb)
            put("isSpeechActive", state.isSpeechActive)
            put("lastLatencyMs", state.lastLatencyMs)
            put("lastRtf", state.lastRtf.toDouble())
            put("activeWindowSec", state.activeWindowSec.toDouble())
            put("timelineDriftMs", state.timelineDriftMs)
            put("pssMemoryMb", state.pssMemoryMb.toDouble())
            put("isOverlayActive", state.isOverlayActive)
            put("systemAudioSilentWarning", state.systemAudioSilentWarning)
            put("statusMessage", state.statusMessage)
            put("segments", segArray)
        }.toString()
    }
}
