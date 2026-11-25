package com.example.offlinesubtitle.bridge

import android.app.Application
import android.content.Intent
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import com.example.offlinesubtitle.asr.BackendTag
import com.example.offlinesubtitle.asr.LocalModelProfile
import com.example.offlinesubtitle.audio.AudioInputSource
import com.example.offlinesubtitle.export.SubtitleExportFormat
import com.example.offlinesubtitle.service.SubtitleRuntimeCoordinator
import com.example.offlinesubtitle.subtitle.SubtitleUiState
import kotlinx.coroutines.flow.StateFlow

class OfflineSubtitleViewModel(application: Application) : AndroidViewModel(application) {

    val bridge: OfflineSubtitleBridge =
        SubtitleRuntimeCoordinator.getOrCreateBridge(application.applicationContext)

    val uiState: StateFlow<SubtitleUiState> = bridge.uiState
    val bridgeState: StateFlow<BridgeControlState> = bridge.bridgeState

    fun attachHost(callbacks: BridgeHostCallbacks) = bridge.attachHost(callbacks)
    fun detachHost() = bridge.detachHost()

    fun onPickModelFolderClick() = bridge.handlePickModelFolderClick()
    fun onModelFolderPicked(treeUri: Uri) = bridge.handleModelFolderPicked(treeUri)
    fun onApplyModelPath(path: String) = bridge.handleApplyModelPath(path)
    fun onResetModelPath() = bridge.handleResetModelPath()

    fun onStartStopClick(hasMicPermission: Boolean) = bridge.handleStartOrStopToggle(hasMicPermission)
    fun onMediaProjectionGranted(resultCode: Int, data: Intent) =
        bridge.handleMediaProjectionGranted(resultCode, data)

    fun onToggleOverlay() = bridge.handleToggleOverlay()
    fun onImportAudioClick() = bridge.handleImportAudioClick()
    fun onAudioUriPicked(uri: Uri) = bridge.handleAudioUriPicked(uri)
    fun onSwitchToMockModel() = bridge.handleSwitchToMockModel()
    fun onSwitchToLocalModel(profile: LocalModelProfile) = bridge.handleSwitchToLocalModel(profile)
    fun onUnloadModel() = bridge.handleUnloadModel()
    fun onSelectInputSource(source: AudioInputSource) = bridge.handleSelectInputSource(source)
    fun onSelectBackend(backendTag: BackendTag) = bridge.handleSelectBackend(backendTag)
    fun onEditSegment(segmentId: Long, newText: String) = bridge.handleEditSegment(segmentId, newText)
    fun onClearSubtitles() = bridge.handleClearSubtitles()
    fun onLoadBuiltInTestMode() = bridge.handleInjectBuiltInTestMode()
    fun onExport(format: SubtitleExportFormat, shareAfter: Boolean) =
        bridge.handleExportSubtitles(format, shareAfter)
    fun onRefreshModels() = bridge.handleRefreshExternalModels()
}
