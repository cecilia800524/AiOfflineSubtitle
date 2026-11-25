package com.example.offlinesubtitle.ui

import android.annotation.SuppressLint
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.example.offlinesubtitle.asr.LocalModelProfile
import com.example.offlinesubtitle.audio.AudioInputSource
import com.example.offlinesubtitle.bridge.BridgeControlState
import com.example.offlinesubtitle.bridge.OfflineSubtitleBridge
import com.example.offlinesubtitle.subtitle.SubtitleUiState

@Composable
fun OfflineSubtitleBridgeScreen(
    bridge: OfflineSubtitleBridge,
    uiState: SubtitleUiState,
    bridgeState: BridgeControlState,
    hasMicPermission: Boolean
) {
    var showEmbeddedWebUi by remember { mutableStateOf(true) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            FilterChip(
                selected = showEmbeddedWebUi,
                onClick = { showEmbeddedWebUi = true },
                label = { Text("離線 WebView Bridge UI") }
            )
            FilterChip(
                selected = !showEmbeddedWebUi,
                onClick = { showEmbeddedWebUi = false },
                label = { Text("State Handlers 檢視") }
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        if (showEmbeddedWebUi) {
            EmbeddedBridgeWebView(
                bridge = bridge,
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
            )
        } else {
            BridgeStateHandlersInspector(
                bridge = bridge,
                uiState = uiState,
                bridgeState = bridgeState,
                hasMicPermission = hasMicPermission,
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun BridgeStateHandlersInspector(
    bridge: OfflineSubtitleBridge,
    uiState: SubtitleUiState,
    bridgeState: BridgeControlState,
    hasMicPermission: Boolean,
    modifier: Modifier = Modifier
) {
    LazyColumn(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        contentPadding = PaddingValues(bottom = 12.dp)
    ) {
        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text(
                        text = "OfflineSubtitleBridge 連動狀態",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = "MainActivity Host: ${if (bridgeState.isHostAttached) "已綁定" else "未綁定"}",
                        style = MaterialTheme.typography.bodySmall
                    )
                    Text(
                        text = "ForegroundService 狀態: ${bridgeState.serviceLifecycleState}",
                        style = MaterialTheme.typography.bodySmall
                    )
                    Text(
                        text = "目前模型路徑 (${if (uiState.isCustomModelPath) "自訂" else "預設"}): ${uiState.currentModelPath}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Text(
                        text = "最近指令: ${bridgeState.lastCommand}",
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
        }

        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text(
                        text = "Bridge State Handlers 快速驗證",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.height(8.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedButton(
                            onClick = {
                                if (uiState.isRunning) {
                                    bridge.handleStopService()
                                } else {
                                    bridge.handleStartService(AudioInputSource.SIMULATED_PCM)
                                }
                            },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text(if (uiState.isRunning) "停止服務" else "模擬音訊啟動")
                        }
                        OutlinedButton(
                            onClick = { bridge.handleStartOrStopToggle(hasMicPermission) },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("Mic 切換")
                        }
                    }

                    Spacer(modifier = Modifier.height(6.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedButton(
                            onClick = { bridge.handleSwitchToLocalModel(LocalModelProfile.WHISPER_TINY_QNN) },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("載入 Whisper Tiny")
                        }
                        OutlinedButton(
                            onClick = { bridge.handleToggleOverlay() },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text(if (uiState.isOverlayActive) "關閉懸浮窗" else "開啟懸浮窗")
                        }
                    }

                    Spacer(modifier = Modifier.height(6.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedButton(
                            onClick = { bridge.handlePickModelFolderClick() },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("SAF 選取模型目錄")
                        }
                        OutlinedButton(
                            onClick = { bridge.handleResetModelPath() },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("重設預設路徑")
                        }
                    }
                }
            }
        }

        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLowest),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text(
                        text = "即時橋接 JSON 狀態快照",
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = bridgeState.lastSerializedStateJson,
                        style = MaterialTheme.typography.bodySmall,
                        fontFamily = FontFamily.Monospace,
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(8.dp))
                            .padding(8.dp)
                    )
                }
            }
        }

        if (bridgeState.commandHistory.isNotEmpty()) {
            item {
                Text(
                    text = "近期 State Handler 指令軌跡",
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold
                )
            }
            items(bridgeState.commandHistory) { cmd ->
                Text(
                    text = "• $cmd",
                    style = MaterialTheme.typography.bodySmall,
                    fontFamily = FontFamily.Monospace
                )
            }
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun EmbeddedBridgeWebView(
    bridge: OfflineSubtitleBridge,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val webView = remember {
        WebView(context).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.allowFileAccess = true
            webViewClient = WebViewClient()
            addJavascriptInterface(bridge, OfflineSubtitleBridge.JS_INTERFACE_NAME)
            loadUrl("file:///android_asset/bridge/index.html")
        }
    }

    DisposableEffect(webView) {
        bridge.attachWebView(webView)
        onDispose {
            bridge.detachWebView(webView)
            webView.removeJavascriptInterface(OfflineSubtitleBridge.JS_INTERFACE_NAME)
            webView.destroy()
        }
    }

    AndroidView(
        factory = { webView },
        modifier = modifier
    )
}
