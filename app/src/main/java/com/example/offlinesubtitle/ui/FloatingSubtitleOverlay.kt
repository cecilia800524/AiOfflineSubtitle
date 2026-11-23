package com.example.offlinesubtitle.ui

import android.content.Context
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.WindowManager
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DragIndicator
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.example.offlinesubtitle.audio.AudioInputSource
import com.example.offlinesubtitle.subtitle.SubtitleStateManager
import kotlin.math.roundToInt

class FloatingSubtitleOverlay(
    private val context: Context,
    private val stateManager: SubtitleStateManager,
    private val onSwitchSourceRequest: (AudioInputSource) -> Unit,
    private val onCloseOverlay: () -> Unit
) {
    private val windowManager = context.getSystemService(WindowManager::class.java)
    private var composeView: ComposeView? = null
    private var overlayLifecycleOwner: OverlayLifecycleOwner? = null
    private var layoutParams: WindowManager.LayoutParams? = null

    val isShowing: Boolean
        get() = composeView != null

    fun show() {
        if (composeView != null) return

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            x = 0
            y = 180
        }
        layoutParams = params

        val lifecycleOwner = OverlayLifecycleOwner().apply {
            performRestore()
            handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
            handleLifecycleEvent(Lifecycle.Event.ON_START)
            handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
        }
        overlayLifecycleOwner = lifecycleOwner

        val view = ComposeView(context).apply {
            setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnDetachedFromWindow)
            setViewTreeLifecycleOwner(lifecycleOwner)
            setViewTreeSavedStateRegistryOwner(lifecycleOwner)
            setContent {
                MaterialTheme {
                    val uiState by stateManager.uiState.collectAsStateWithLifecycle()
                    FloatingOverlayCard(
                        latestText = uiState.segments.lastOrNull()?.text ?: "正在等待語音輸入...",
                        previousText = uiState.segments.dropLast(1).lastOrNull()?.text,
                        isDraft = uiState.segments.lastOrNull()?.isFinal == false,
                        inputSource = uiState.inputSource,
                        latencyMs = uiState.lastLatencyMs,
                        onDrag = { dx, dy ->
                            params.x += dx
                            params.y += dy
                            runCatching { windowManager.updateViewLayout(this, params) }
                        },
                        onToggleSource = {
                            val next = if (uiState.inputSource == AudioInputSource.MICROPHONE) {
                                AudioInputSource.SYSTEM_AUDIO
                            } else {
                                AudioInputSource.MICROPHONE
                            }
                            onSwitchSourceRequest(next)
                        },
                        onClose = onCloseOverlay
                    )
                }
            }
        }
        composeView = view
        windowManager.addView(view, params)
    }

    fun hide() {
        val view = composeView ?: return
        runCatching { windowManager.removeView(view) }
        composeView = null
        overlayLifecycleOwner?.apply {
            handleLifecycleEvent(Lifecycle.Event.ON_PAUSE)
            handleLifecycleEvent(Lifecycle.Event.ON_STOP)
            handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
        }
        overlayLifecycleOwner = null
        layoutParams = null
    }

    private class OverlayLifecycleOwner : LifecycleOwner, SavedStateRegistryOwner {
        private val lifecycleRegistry = LifecycleRegistry(this)
        private val savedStateController = SavedStateRegistryController.create(this)

        override val lifecycle: Lifecycle
            get() = lifecycleRegistry

        override val savedStateRegistry: SavedStateRegistry
            get() = savedStateController.savedStateRegistry

        fun performRestore() {
            savedStateController.performRestore(null)
        }

        fun handleLifecycleEvent(event: Lifecycle.Event) {
            lifecycleRegistry.handleLifecycleEvent(event)
        }
    }
}

@Composable
private fun FloatingOverlayCard(
    latestText: String,
    previousText: String?,
    isDraft: Boolean,
    inputSource: AudioInputSource,
    latencyMs: Long,
    onDrag: (dx: Int, dy: Int) -> Unit,
    onToggleSource: () -> Unit,
    onClose: () -> Unit
) {
    var isCollapsed by remember { mutableStateOf(false) }

    Surface(
        color = Color(0xCC121417),
        shape = RoundedCornerShape(16.dp),
        shadowElevation = 8.dp,
        modifier = Modifier
            .widthIn(min = 260.dp, max = 350.dp)
            .clip(RoundedCornerShape(16.dp))
            .pointerInput(Unit) {
                detectDragGestures { change, dragAmount ->
                    change.consume()
                    onDrag(dragAmount.x.roundToInt(), dragAmount.y.roundToInt())
                }
            }
    ) {
        Column(modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.DragIndicator,
                        contentDescription = "拖曳懸浮窗",
                        tint = Color(0xFFB0BEC5),
                        modifier = Modifier.size(16.dp)
                    )
                    Text(
                        text = "${inputSource.label} • ${latencyMs}ms",
                        style = MaterialTheme.typography.labelSmall,
                        color = Color(0xFF81D4FA),
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(start = 4.dp)
                    )
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = onToggleSource, modifier = Modifier.size(26.dp)) {
                        Icon(
                            imageVector = Icons.Default.SwapHoriz,
                            contentDescription = "切換音源",
                            tint = Color.White,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                    IconButton(
                        onClick = { isCollapsed = !isCollapsed },
                        modifier = Modifier.size(26.dp)
                    ) {
                        Icon(
                            imageVector = if (isCollapsed) Icons.Default.ExpandMore else Icons.Default.ExpandLess,
                            contentDescription = if (isCollapsed) "展開" else "收合",
                            tint = Color.White,
                            modifier = Modifier.size(18.dp)
                        )
                    }
                    IconButton(onClick = onClose, modifier = Modifier.size(26.dp)) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "關閉懸浮窗",
                            tint = Color(0xFFEF9A9A),
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }

            if (!isCollapsed) {
                Spacer(modifier = Modifier.height(4.dp))
                if (!previousText.isNullOrBlank()) {
                    Text(
                        text = previousText,
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFFBDBDBD),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                }
                Text(
                    text = latestText,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    fontStyle = if (isDraft) FontStyle.Italic else FontStyle.Normal,
                    color = if (isDraft) Color(0xFFFFF59D) else Color.White,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color(0x33FFFFFF), RoundedCornerShape(8.dp))
                        .padding(horizontal = 8.dp, vertical = 6.dp)
                )
            }
        }
    }
}
