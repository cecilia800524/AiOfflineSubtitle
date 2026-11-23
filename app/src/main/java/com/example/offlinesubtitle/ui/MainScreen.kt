package com.example.offlinesubtitle.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AudioFile
import androidx.compose.material.icons.filled.DeleteOutline
import androidx.compose.material.icons.filled.Eject
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.PictureInPictureAlt
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.example.offlinesubtitle.asr.BackendTag
import com.example.offlinesubtitle.asr.LocalModelProfile
import com.example.offlinesubtitle.asr.SubtitleSegment
import com.example.offlinesubtitle.audio.AudioInputSource
import com.example.offlinesubtitle.export.SubtitleExportFormat
import com.example.offlinesubtitle.subtitle.SubtitleUiState
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen(
    uiState: SubtitleUiState,
    hasMicPermission: Boolean,
    exportStatusMessage: String?,
    onRequestMicPermission: () -> Unit,
    onStartStopClick: () -> Unit,
    onToggleOverlayClick: () -> Unit,
    onImportAudioClick: () -> Unit,
    onSwitchToMockModel: () -> Unit,
    onSwitchToLocalModel: (LocalModelProfile) -> Unit,
    onUnloadModelClick: () -> Unit,
    onSelectInputSource: (AudioInputSource) -> Unit,
    onSelectBackend: (BackendTag) -> Unit,
    onClearClick: () -> Unit,
    onEditSegment: (Long, String) -> Unit,
    onExportAndSave: (SubtitleExportFormat) -> Unit,
    onExportAndShare: (SubtitleExportFormat) -> Unit,
    onLoadBuiltInTestMode: () -> Unit
) {
    var selectedTab by remember { mutableIntStateOf(0) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = "OfflineSubtitle 離線即時字幕",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = uiState.statusMessage,
                            style = MaterialTheme.typography.labelSmall,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                actions = {
                    IconButton(onClick = onToggleOverlayClick) {
                        Icon(
                            imageVector = Icons.Default.PictureInPictureAlt,
                            contentDescription = "切換懸浮字幕窗",
                            tint = if (uiState.isOverlayActive) {
                                MaterialTheme.colorScheme.primary
                            } else {
                                MaterialTheme.colorScheme.onSurfaceVariant
                            }
                        )
                    }
                    IconButton(onClick = onClearClick, enabled = uiState.segments.isNotEmpty()) {
                        Icon(
                            imageVector = Icons.Default.DeleteOutline,
                            contentDescription = "清除字幕"
                        )
                    }
                }
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            TabRow(selectedTabIndex = selectedTab) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    text = { Text("即時字幕與背景服務") }
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    text = { Text("編輯與匯出 (${uiState.segments.size})") }
                )
            }

            if (selectedTab == 0) {
                LiveCaptionTabContent(
                    uiState = uiState,
                    hasMicPermission = hasMicPermission,
                    onRequestMicPermission = onRequestMicPermission,
                    onStartStopClick = onStartStopClick,
                    onImportAudioClick = onImportAudioClick,
                    onSwitchToMockModel = onSwitchToMockModel,
                    onSwitchToLocalModel = onSwitchToLocalModel,
                    onUnloadModelClick = onUnloadModelClick,
                    onSelectInputSource = onSelectInputSource,
                    onSelectBackend = onSelectBackend
                )
            } else {
                TranscriptEditorScreen(
                    segments = uiState.segments,
                    exportStatusMessage = exportStatusMessage,
                    onEditSegment = onEditSegment,
                    onExportAndSave = onExportAndSave,
                    onExportAndShare = onExportAndShare,
                    onLoadBuiltInTestMode = onLoadBuiltInTestMode
                )
            }
        }
    }
}

@Composable
private fun LiveCaptionTabContent(
    uiState: SubtitleUiState,
    hasMicPermission: Boolean,
    onRequestMicPermission: () -> Unit,
    onStartStopClick: () -> Unit,
    onImportAudioClick: () -> Unit,
    onSwitchToMockModel: () -> Unit,
    onSwitchToLocalModel: (LocalModelProfile) -> Unit,
    onUnloadModelClick: () -> Unit,
    onSelectInputSource: (AudioInputSource) -> Unit,
    onSelectBackend: (BackendTag) -> Unit
) {
    val listState = rememberLazyListState()

    LaunchedEffect(uiState.segments.size, uiState.segments.lastOrNull()?.text) {
        if (uiState.segments.isNotEmpty()) {
            listState.animateScrollToItem(uiState.segments.lastIndex)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp)
    ) {
        Spacer(modifier = Modifier.height(10.dp))

        TelemetryStatusBanner(uiState = uiState)

        if (uiState.systemAudioSilentWarning) {
            Spacer(modifier = Modifier.height(6.dp))
            Surface(
                color = Color(0xFFFFEBEE),
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = "偵測到系統音訊持續靜音：目標 App 可能受 DRM 保護或禁止音訊內錄",
                    style = MaterialTheme.typography.labelSmall,
                    color = Color(0xFFC62828),
                    modifier = Modifier.padding(8.dp)
                )
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        ModelAndFileActionRow(
            uiState = uiState,
            onImportAudioClick = onImportAudioClick,
            onSwitchToMockModel = onSwitchToMockModel,
            onSwitchToLocalModel = onSwitchToLocalModel,
            onUnloadModelClick = onUnloadModelClick
        )

        Spacer(modifier = Modifier.height(6.dp))

        ControlOptionsRow(
            uiState = uiState,
            onSelectInputSource = onSelectInputSource,
            onSelectBackend = onSelectBackend
        )

        if (uiState.isFileTranscribing) {
            Spacer(modifier = Modifier.height(6.dp))
            LinearProgressIndicator(
                progress = { uiState.fileTranscribeProgress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(6.dp)
                    .clip(RoundedCornerShape(3.dp))
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(MaterialTheme.colorScheme.surfaceContainerLowest)
        ) {
            if (uiState.segments.isEmpty()) {
                EmptySubtitlePlaceholder(
                    modifier = Modifier.align(Alignment.Center),
                    isRunning = uiState.isRunning
                )
            } else {
                LazyColumn(
                    state = listState,
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier.fillMaxSize()
                ) {
                    items(
                        items = uiState.segments,
                        key = { it.id }
                    ) { segment ->
                        SubtitleItemCard(segment = segment)
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        BottomActionBar(
            isRunning = uiState.isRunning,
            isBusy = uiState.isFileTranscribing,
            inputSource = uiState.inputSource,
            needsMicPermission = uiState.inputSource == AudioInputSource.MICROPHONE && !hasMicPermission,
            onRequestMicPermission = onRequestMicPermission,
            onStartStopClick = onStartStopClick
        )

        Spacer(modifier = Modifier.height(12.dp))
    }
}

@Composable
private fun TelemetryStatusBanner(uiState: SubtitleUiState) {
    val latencyColor = when {
        uiState.lastLatencyMs == 0L -> MaterialTheme.colorScheme.onSurfaceVariant
        uiState.lastLatencyMs < 800L -> Color(0xFF1B873F)
        else -> Color(0xFFD93025)
    }

    val rtfColor = when {
        uiState.lastRtf <= 0f -> MaterialTheme.colorScheme.onSurfaceVariant
        uiState.lastRtf < 0.30f -> Color(0xFF1B873F)
        else -> Color(0xFFD93025)
    }

    val vadColor by animateColorAsState(
        targetValue = if (uiState.isSpeechActive) Color(0xFF1B873F) else MaterialTheme.colorScheme.outline,
        label = "vadColor"
    )

    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Surface(
                    color = if (uiState.backendTag == BackendTag.QNN_NPU) Color(0xFFE3F2FD) else Color(0xFFFFF3E0),
                    shape = RoundedCornerShape(6.dp)
                ) {
                    Text(
                        text = "${uiState.backendTag.label} (${if (uiState.isModelLoaded) "已載入" else "未載入"})",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = if (uiState.backendTag == BackendTag.QNN_NPU) Color(0xFF0D47A1) else Color(0xFFE65100),
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }

                Text(
                    text = "延遲: ${uiState.lastLatencyMs}ms",
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Bold,
                    color = latencyColor
                )

                Text(
                    text = String.format(Locale.US, "RTF: %.3f", uiState.lastRtf),
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Bold,
                    color = rtfColor
                )
            }

            Spacer(modifier = Modifier.height(6.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = String.format(
                        Locale.US,
                        "模型: %.1fMB | PSS: %.1fMB | 漂移: %dms",
                        uiState.modelsDiskSizeMb,
                        uiState.pssMemoryMb,
                        uiState.timelineDriftMs
                    ),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(vadColor)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = if (uiState.isSpeechActive) "語音" else "靜音",
                        style = MaterialTheme.typography.labelSmall
                    )
                }
            }

            Spacer(modifier = Modifier.height(6.dp))

            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = String.format(Locale.US, "視窗 %.1fs / 30s", uiState.activeWindowSec),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.width(96.dp)
                )
                LinearProgressIndicator(
                    progress = { (uiState.activeWindowSec / 30f).coerceIn(0f, 1f) },
                    modifier = Modifier
                        .weight(1f)
                        .height(6.dp)
                        .clip(RoundedCornerShape(3.dp))
                )
            }
        }
    }
}

@Composable
private fun ModelAndFileActionRow(
    uiState: SubtitleUiState,
    onImportAudioClick: () -> Unit,
    onSwitchToMockModel: () -> Unit,
    onSwitchToLocalModel: (LocalModelProfile) -> Unit,
    onUnloadModelClick: () -> Unit
) {
    var modelMenuExpanded by remember { mutableStateOf(false) }
    val controlsEnabled = !uiState.isRunning && !uiState.isFileTranscribing

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        OutlinedButton(
            onClick = onImportAudioClick,
            enabled = controlsEnabled,
            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
            modifier = Modifier.weight(1f)
        ) {
            Icon(Icons.Default.AudioFile, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(modifier = Modifier.width(4.dp))
            Text("匯入音檔測試", style = MaterialTheme.typography.labelMedium, maxLines = 1)
        }

        Box {
            OutlinedButton(
                onClick = { modelMenuExpanded = true },
                enabled = controlsEnabled,
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp)
            ) {
                Icon(Icons.Default.Memory, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text("切換模型", style = MaterialTheme.typography.labelMedium)
            }
            DropdownMenu(
                expanded = modelMenuExpanded,
                onDismissRequest = { modelMenuExpanded = false }
            ) {
                DropdownMenuItem(
                    text = { Text("Mock NPU (免模型原型測試)") },
                    onClick = {
                        modelMenuExpanded = false
                        onSwitchToMockModel()
                    }
                )
                LocalModelProfile.entries.forEach { profile ->
                    DropdownMenuItem(
                        text = { Text(profile.displayName) },
                        onClick = {
                            modelMenuExpanded = false
                            onSwitchToLocalModel(profile)
                        }
                    )
                }
            }
        }

        OutlinedButton(
            onClick = onUnloadModelClick,
            enabled = controlsEnabled && uiState.isModelLoaded,
            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp)
        ) {
            Icon(Icons.Default.Eject, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(modifier = Modifier.width(4.dp))
            Text("卸載", style = MaterialTheme.typography.labelMedium)
        }
    }
}

@Composable
private fun ControlOptionsRow(
    uiState: SubtitleUiState,
    onSelectInputSource: (AudioInputSource) -> Unit,
    onSelectBackend: (BackendTag) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        AudioInputSource.entries.forEach { source ->
            FilterChip(
                selected = uiState.inputSource == source,
                onClick = { onSelectInputSource(source) },
                enabled = !uiState.isRunning && !uiState.isFileTranscribing,
                label = { Text(source.label, style = MaterialTheme.typography.labelSmall) }
            )
        }

        Spacer(modifier = Modifier.weight(1f))

        FilterChip(
            selected = uiState.backendTag == BackendTag.QNN_NPU,
            onClick = {
                val next = if (uiState.backendTag == BackendTag.QNN_NPU) {
                    BackendTag.CPU_FALLBACK
                } else {
                    BackendTag.QNN_NPU
                }
                onSelectBackend(next)
            },
            label = {
                Text(
                    text = if (uiState.backendTag == BackendTag.QNN_NPU) "NPU" else "CPU",
                    style = MaterialTheme.typography.labelSmall
                )
            }
        )
    }
}

@Composable
private fun SubtitleItemCard(segment: SubtitleSegment) {
    val containerColor = if (segment.isFinal) {
        MaterialTheme.colorScheme.surfaceContainer
    } else {
        MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.45f)
    }

    Card(
        colors = CardDefaults.cardColors(containerColor = containerColor),
        shape = RoundedCornerShape(10.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "${formatTimestamp(segment.startTimeMs)} → ${formatTimestamp(segment.endTimeMs)}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Text(
                    text = if (segment.isFinal) {
                        "FINAL • ${segment.backendTag.label} • ${segment.latencyMs}ms"
                    } else {
                        "DRAFT • ${segment.latencyMs}ms"
                    },
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = if (segment.isFinal) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (segment.isFinal) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.tertiary
                )
            }

            Spacer(modifier = Modifier.height(6.dp))

            Text(
                text = segment.text,
                style = MaterialTheme.typography.bodyLarge,
                fontStyle = if (segment.isFinal) FontStyle.Normal else FontStyle.Italic,
                color = MaterialTheme.colorScheme.onSurface
            )
        }
    }
}

@Composable
private fun EmptySubtitlePlaceholder(
    modifier: Modifier = Modifier,
    isRunning: Boolean
) {
    Column(
        modifier = modifier.padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = Icons.Default.GraphicEq,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.outline,
            modifier = Modifier.size(48.dp)
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = if (isRunning) {
                "前景服務運作中，偵測到語音後將即時顯示字幕..."
            } else {
                "選擇「麥克風 / 系統音訊 / 模擬音訊」並點擊開始；可隨時開啟右上角懸浮窗"
            },
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun BottomActionBar(
    isRunning: Boolean,
    isBusy: Boolean,
    inputSource: AudioInputSource,
    needsMicPermission: Boolean,
    onRequestMicPermission: () -> Unit,
    onStartStopClick: () -> Unit
) {
    if (needsMicPermission) {
        Button(
            onClick = onRequestMicPermission,
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
        ) {
            Icon(imageVector = Icons.Default.Mic, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text("授予麥克風權限以啟動前景字幕服務")
        }
    } else {
        Button(
            onClick = onStartStopClick,
            enabled = !isBusy,
            colors = if (isRunning) {
                ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
            } else {
                ButtonDefaults.buttonColors()
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
        ) {
            Icon(
                imageVector = if (isRunning) Icons.Default.Stop else Icons.Default.Mic,
                contentDescription = null
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                if (isRunning) "停止背景服務與字幕" else "啟動${inputSource.label}字幕服務"
            )
        }
    }
}

private fun formatTimestamp(ms: Long): String {
    val totalSec = ms / 1000L
    val min = totalSec / 60L
    val sec = totalSec % 60L
    val tenth = (ms % 1000L) / 100L
    return String.format(Locale.US, "%02d:%02d.%d", min, sec, tenth)
}
