package com.example.offlinesubtitle.asr

import android.os.SystemClock
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

enum class BackendTag(val label: String) {
    QNN_NPU("QNN_NPU"),
    CPU_FALLBACK("CPU_FALLBACK")
}

data class SubtitleSegment(
    val id: Long,
    val text: String,
    val isFinal: Boolean,
    val startTimeMs: Long,
    val endTimeMs: Long,
    val backendTag: BackendTag,
    val latencyMs: Long
)

interface AsrEngine {
    val currentBackend: BackendTag

    suspend fun initialize(): Result<Unit>

    suspend fun transcribe(
        pcm16kMono: ShortArray,
        segmentId: Long,
        startTimeMs: Long,
        endTimeMs: Long,
        isFinalTrigger: Boolean
    ): SubtitleSegment

    fun setBackendMode(backendTag: BackendTag)

    fun release()
}

class MockNpuAsrEngine : AsrEngine {

    companion object {
        private const val TAG_PERF = "[ASR_PERF]"
        private const val SAMPLE_RATE = 16_000L

        private val CODE_SWITCHING_SCRIPTS = listOf(
            "大家好，今天我們在 Snapdragon 8s Gen 4 裝置上測試離線即時字幕系統，透過 Hexagon NPU 與 QNN 加速推論效能。",
            "目前音訊管線採用 16kHz Mono PCM 格式輸入，並搭配 VAD 偵測進行靜音過濾與 30 秒滑動視窗切分。",
            "在 Jetpack Compose 介面中，我們將 Draft 草稿字幕與 Final 定稿字幕分離，確保端到端延遲低於 800ms。",
            "這套架構完全不依賴 Cloud API 或網路連線，支援繁體中文與 English 技術名詞混合辨識。",
            "當講者連續發言超過 30 秒邊界時，系統會保留最後 2 秒的重疊音訊緩衝，避免關鍵字詞被截斷。"
        )
    }

    @Volatile
    private var backendMode: BackendTag = BackendTag.QNN_NPU

    override val currentBackend: BackendTag
        get() = backendMode

    override suspend fun initialize(): Result<Unit> = withContext(Dispatchers.Default) {
        val start = SystemClock.elapsedRealtime()
        delay(60L)
        val cost = SystemClock.elapsedRealtime() - start
        Log.i(TAG_PERF, "MockNpuAsrEngine initialized in ${cost}ms, Backend=${backendMode.label}")
        Result.success(Unit)
    }

    override fun setBackendMode(backendTag: BackendTag) {
        backendMode = backendTag
        Log.i(TAG_PERF, "Switched ASR Backend=${backendTag.label}")
    }

    override suspend fun transcribe(
        pcm16kMono: ShortArray,
        segmentId: Long,
        startTimeMs: Long,
        endTimeMs: Long,
        isFinalTrigger: Boolean
    ): SubtitleSegment = withContext(Dispatchers.Default) {
        val inferStartMs = SystemClock.elapsedRealtime()
        val audioDurationMs = (pcm16kMono.size * 1000L) / SAMPLE_RATE

        val simulatedComputeMs = when (backendMode) {
            BackendTag.QNN_NPU -> (65L + audioDurationMs / 40L).coerceIn(70L, 260L)
            BackendTag.CPU_FALLBACK -> (240L + audioDurationMs / 10L).coerceIn(250L, 950L)
        }
        delay(simulatedComputeMs)

        val script = CODE_SWITCHING_SCRIPTS[((segmentId - 1L).coerceAtLeast(0L) % CODE_SWITCHING_SCRIPTS.size).toInt()]
        val targetDurationForFullScriptMs = 6_500L
        val progress = if (isFinalTrigger && audioDurationMs >= 3_500L) {
            1.0f
        } else {
            (audioDurationMs.toFloat() / targetDurationForFullScriptMs.toFloat()).coerceIn(0.18f, 1.0f)
        }

        val charCount = (script.length * progress).toInt().coerceIn(4, script.length)
        val recognizedText = script.substring(0, charCount)

        val inferLatencyMs = SystemClock.elapsedRealtime() - inferStartMs
        val rtf = if (audioDurationMs > 0L) inferLatencyMs.toFloat() / audioDurationMs.toFloat() else 0f

        Log.d(
            TAG_PERF,
            "Backend=${backendMode.label} seg=$segmentId final=$isFinalTrigger " +
                "audioMs=$audioDurationMs inferMs=$inferLatencyMs rtf=${"%.3f".format(rtf)}"
        )

        SubtitleSegment(
            id = segmentId,
            text = recognizedText,
            isFinal = isFinalTrigger,
            startTimeMs = startTimeMs,
            endTimeMs = endTimeMs,
            backendTag = backendMode,
            latencyMs = inferLatencyMs
        )
    }

    override fun release() {
        Log.i(TAG_PERF, "MockNpuAsrEngine released")
    }
}
