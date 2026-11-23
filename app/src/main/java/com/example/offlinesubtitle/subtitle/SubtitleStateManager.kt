package com.example.offlinesubtitle.subtitle

import android.media.projection.MediaProjection
import android.os.SystemClock
import android.util.Log
import com.example.offlinesubtitle.asr.AsrEngine
import com.example.offlinesubtitle.asr.BackendTag
import com.example.offlinesubtitle.asr.FileTranscriptionReport
import com.example.offlinesubtitle.asr.LocalModelProfile
import com.example.offlinesubtitle.asr.LocalNpuAsrEngine
import com.example.offlinesubtitle.asr.SubtitleSegment
import com.example.offlinesubtitle.audio.AudioCaptureManager
import com.example.offlinesubtitle.audio.AudioFrameChunk
import com.example.offlinesubtitle.audio.AudioInputSource
import com.example.offlinesubtitle.audio.VadTransition
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.abs

data class SubtitleUiState(
    val isRunning: Boolean = false,
    val isFileTranscribing: Boolean = false,
    val fileTranscribeProgress: Float = 0f,
    val inputSource: AudioInputSource = AudioInputSource.MICROPHONE,
    val backendTag: BackendTag = BackendTag.QNN_NPU,
    val activeEngineLabel: String = "Mock NPU",
    val isModelLoaded: Boolean = true,
    val modelsDiskSizeMb: Double = 0.0,
    val isSpeechActive: Boolean = false,
    val latestRms: Float = 0f,
    val lastLatencyMs: Long = 0L,
    val lastRtf: Float = 0f,
    val activeWindowSec: Float = 0f,
    val timelineDriftMs: Long = 0L,
    val pssMemoryMb: Float = 0f,
    val isOverlayActive: Boolean = false,
    val systemAudioSilentWarning: Boolean = false,
    val segments: List<SubtitleSegment> = emptyList(),
    val statusMessage: String = "待命中"
)

class SubtitleStateManager(
    private val audioCaptureManager: AudioCaptureManager,
    initialEngine: AsrEngine,
    private val localNpuAsrEngine: LocalNpuAsrEngine? = null
) {
    companion object {
        private const val TAG_PERF = "[ASR_PERF]"
        private const val TAG_STATE = "[ASR_STATE]"

        const val SAMPLE_RATE = AudioCaptureManager.SAMPLE_RATE
        const val MAX_WINDOW_SAMPLES = 30 * SAMPLE_RATE
        const val OVERLAP_SAMPLES = 2 * SAMPLE_RATE
        private const val MIN_INFER_SAMPLES = 3_200
        private const val DRAFT_INTERVAL_MS = 500L
        private const val DRIFT_CORRECTION_THRESHOLD_MS = 180L
    }

    private sealed class InferTask {
        abstract val pcmSnapshot: ShortArray
        abstract val segmentId: Long
        abstract val startTimeMs: Long
        abstract val endTimeMs: Long
        abstract val audioEntryTimestampMs: Long

        data class Draft(
            override val pcmSnapshot: ShortArray,
            override val segmentId: Long,
            override val startTimeMs: Long,
            override val endTimeMs: Long,
            override val audioEntryTimestampMs: Long
        ) : InferTask()

        data class Final(
            override val pcmSnapshot: ShortArray,
            override val segmentId: Long,
            override val startTimeMs: Long,
            override val endTimeMs: Long,
            override val audioEntryTimestampMs: Long,
            val reason: String
        ) : InferTask()
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val bufferMutex = Mutex()
    private val segmentIdGen = AtomicLong(0L)
    private val isDraftInFlight = AtomicBoolean(false)

    @Volatile
    private var activeAsrEngine: AsrEngine = initialEngine

    private val windowBuffer = ShortArray(MAX_WINDOW_SAMPLES + SAMPLE_RATE)
    private var windowSampleCount = 0
    private var windowStartTotalSamples = 0L
    private var totalCapturedSamples = 0L
    private var sessionStartElapsedMs = 0L
    private var accumulatedDriftCorrectionMs = 0L
    private var currentActiveSegmentId = 0L
    private var lastDraftDispatchMs = 0L
    private var hasSpeechInWindow = false

    private var captureJob: Job? = null
    private var inferConsumerJob: Job? = null
    private var inferChannel = Channel<InferTask>(Channel.UNLIMITED)

    private val _uiState = MutableStateFlow(
        SubtitleUiState(
            backendTag = initialEngine.currentBackend,
            modelsDiskSizeMb = localNpuAsrEngine?.calculateModelsDiskUsageMb() ?: 0.0
        )
    )
    val uiState: StateFlow<SubtitleUiState> = _uiState.asStateFlow()

    fun getCurrentEngine(): AsrEngine = activeAsrEngine

    fun refreshModelDiskUsage() {
        val sizeMb = localNpuAsrEngine?.calculateModelsDiskUsageMb() ?: 0.0
        _uiState.update { it.copy(modelsDiskSizeMb = sizeMb) }
    }

    fun setOverlayActive(active: Boolean) {
        _uiState.update { it.copy(isOverlayActive = active) }
    }

    fun setInputSource(source: AudioInputSource) {
        _uiState.update { it.copy(inputSource = source) }
    }

    fun setBackendMode(backend: BackendTag) {
        activeAsrEngine.setBackendMode(backend)
        _uiState.update { it.copy(backendTag = backend) }
    }

    fun switchToEngine(engine: AsrEngine, label: String, localProfile: LocalModelProfile? = null) {
        if (_uiState.value.isRunning || _uiState.value.isFileTranscribing) return

        scope.launch {
            _uiState.update { it.copy(statusMessage = "正在切換模型: $label...") }
            if (activeAsrEngine !== engine) {
                activeAsrEngine.release()
            }
            if (engine is LocalNpuAsrEngine && localProfile != null) {
                engine.setProfile(localProfile)
            }

            val initResult = engine.initialize()
            val diskMb = localNpuAsrEngine?.calculateModelsDiskUsageMb() ?: 0.0
            activeAsrEngine = engine

            if (initResult.isSuccess) {
                _uiState.update {
                    it.copy(
                        activeEngineLabel = label,
                        backendTag = engine.currentBackend,
                        isModelLoaded = true,
                        modelsDiskSizeMb = diskMb,
                        statusMessage = "已載入 $label (${engine.currentBackend.label})"
                    )
                }
            } else {
                _uiState.update {
                    it.copy(
                        activeEngineLabel = label,
                        isModelLoaded = false,
                        modelsDiskSizeMb = diskMb,
                        statusMessage = initResult.exceptionOrNull()?.message ?: "載入失敗"
                    )
                }
            }
        }
    }

    fun unloadCurrentModel() {
        if (_uiState.value.isRunning || _uiState.value.isFileTranscribing) return
        activeAsrEngine.release()
        _uiState.update {
            it.copy(
                isModelLoaded = false,
                modelsDiskSizeMb = localNpuAsrEngine?.calculateModelsDiskUsageMb() ?: 0.0,
                statusMessage = "已卸載模型並釋放記憶體"
            )
        }
    }

    fun clearSubtitles() {
        _uiState.update { it.copy(segments = emptyList(), lastLatencyMs = 0L, lastRtf = 0f) }
    }

    fun editSegmentText(segmentId: Long, newText: String) {
        val trimmed = newText.trim()
        if (trimmed.isEmpty()) return
        _uiState.update { state ->
            val updated = state.segments.map { seg ->
                if (seg.id == segmentId) seg.copy(text = trimmed) else seg
            }
            state.copy(segments = updated, statusMessage = "已更新第 #$segmentId 句字幕")
        }
        Log.i(TAG_STATE, "Edited segment id=$segmentId")
    }

    fun injectBuiltInTestSegments() {
        val baseId = segmentIdGen.addAndGet(100L)
        val mockSegments = listOf(
            SubtitleSegment(
                id = baseId + 1,
                text = "歡迎使用 Snapdragon 8s Gen 4 離線即時字幕原型系統。",
                isFinal = true,
                startTimeMs = 0L,
                endTimeMs = 3_400L,
                backendTag = BackendTag.QNN_NPU,
                latencyMs = 112L
            ),
            SubtitleSegment(
                id = baseId + 2,
                text = "這一句刻意帶有 400ms 時間軸重疊，用來測試 SubtitleExporter 連續性自動修正。",
                isFinal = true,
                startTimeMs = 3_000L,
                endTimeMs = 7_200L,
                backendTag = BackendTag.QNN_NPU,
                latencyMs = 135L
            ),
            SubtitleSegment(
                id = baseId + 3,
                text = "我們支援 Qualcomm QNN HTP 加速以及 Jetpack Compose 懸浮視窗疊加顯示。",
                isFinal = true,
                startTimeMs = 7_500L,
                endTimeMs = 11_800L,
                backendTag = BackendTag.QNN_NPU,
                latencyMs = 128L
            ),
            SubtitleSegment(
                id = baseId + 4,
                text = "最後這一段將測試 SRT、VTT 與 TXT 匯出格式與關鍵字 Search 高亮功能。",
                isFinal = true,
                startTimeMs = 12_100L,
                endTimeMs = 16_000L,
                backendTag = BackendTag.CPU_FALLBACK,
                latencyMs = 410L
            )
        )
        _uiState.update {
            it.copy(
                segments = mockSegments,
                lastLatencyMs = 128L,
                lastRtf = 0.042f,
                statusMessage = "已載入內建測試模式資料（含故意重疊時間軸供匯出校驗）"
            )
        }
        Log.i(TAG_STATE, "Injected built-in test segments count=${mockSegments.size}")
    }

    fun updateServiceHeartbeatMetrics(pssMemoryMb: Float) {
        if (!_uiState.value.isRunning || sessionStartElapsedMs == 0L) {
            _uiState.update { it.copy(pssMemoryMb = pssMemoryMb) }
            return
        }
        val wallElapsedMs = SystemClock.elapsedRealtime() - sessionStartElapsedMs
        val audioClockMs = samplesToMs(totalCapturedSamples) + accumulatedDriftCorrectionMs
        val driftMs = wallElapsedMs - audioClockMs

        if (abs(driftMs) >= DRIFT_CORRECTION_THRESHOLD_MS) {
            accumulatedDriftCorrectionMs += driftMs
            Log.w(
                TAG_STATE,
                "Timeline drift corrected: rawDrift=${driftMs}ms, totalCorrection=${accumulatedDriftCorrectionMs}ms"
            )
        }

        _uiState.update {
            it.copy(
                timelineDriftMs = driftMs,
                pssMemoryMb = pssMemoryMb
            )
        }
    }

    fun onFileTranscribeStarted(fileName: String) {
        _uiState.update {
            it.copy(
                isFileTranscribing = true,
                fileTranscribeProgress = 0f,
                statusMessage = "正在離線轉錄: $fileName..."
            )
        }
    }

    fun onFileTranscribeProgress(progress: Float) {
        _uiState.update { it.copy(fileTranscribeProgress = progress) }
    }

    fun onFileTranscribeCompleted(report: FileTranscriptionReport) {
        _uiState.update {
            it.copy(
                isFileTranscribing = false,
                fileTranscribeProgress = 1f,
                lastRtf = report.rtf,
                backendTag = report.backendTag,
                segments = report.segments,
                statusMessage = String.format(
                    Locale.US,
                    "轉錄完成: %s (時長 %.1fs / 耗時 %.1fs / RTF %.3f)",
                    report.fileName,
                    report.audioDurationMs / 1000f,
                    report.processingTimeMs / 1000f,
                    report.rtf
                )
            )
        }
    }

    fun onFileTranscribeFailed(errorMessage: String) {
        _uiState.update {
            it.copy(
                isFileTranscribing = false,
                fileTranscribeProgress = 0f,
                statusMessage = "音檔轉錄失敗: $errorMessage"
            )
        }
    }

    fun start(mediaProjection: MediaProjection? = null) {
        if (_uiState.value.isRunning || _uiState.value.isFileTranscribing) return

        scope.launch {
            if (!_uiState.value.isModelLoaded) {
                val initRes = activeAsrEngine.initialize()
                if (initRes.isFailure) {
                    _uiState.update {
                        it.copy(statusMessage = initRes.exceptionOrNull()?.message ?: "模型未載入")
                    }
                    return@launch
                }
                _uiState.update { it.copy(isModelLoaded = true, backendTag = activeAsrEngine.currentBackend) }
            }

            resetWindowCounters()
            sessionStartElapsedMs = SystemClock.elapsedRealtime()
            inferChannel.close()
            inferChannel = Channel(Channel.UNLIMITED)
            startInferConsumer()

            val source = _uiState.value.inputSource
            _uiState.update {
                it.copy(
                    isRunning = true,
                    systemAudioSilentWarning = false,
                    statusMessage = "背景服務運行中：${source.label}"
                )
            }
            Log.i(TAG_STATE, "Subtitle pipeline started, source=${source.label}")

            captureJob = scope.launch {
                try {
                    audioCaptureManager.startCapture(
                        source = source,
                        mediaProjection = mediaProjection,
                        onSystemZeroSignalWarning = { warn ->
                            _uiState.update { it.copy(systemAudioSilentWarning = warn) }
                        }
                    ).collect { chunk ->
                        handleAudioChunk(chunk)
                    }
                } catch (e: Exception) {
                    Log.e(TAG_STATE, "Audio pipeline error: ${e.message}", e)
                    _uiState.update {
                        it.copy(
                            isRunning = false,
                            isSpeechActive = false,
                            statusMessage = "錯誤：${e.message ?: "音訊擷取失敗"}"
                        )
                    }
                }
            }
        }
    }

    fun stop() {
        if (!_uiState.value.isRunning && captureJob == null) return

        captureJob?.cancel()
        captureJob = null
        audioCaptureManager.stop()

        scope.launch {
            flushRemainingAsFinal()
            inferChannel.close()
            inferConsumerJob?.join()
            inferConsumerJob = null

            _uiState.update {
                it.copy(
                    isRunning = false,
                    isSpeechActive = false,
                    activeWindowSec = 0f,
                    systemAudioSilentWarning = false,
                    statusMessage = "已停止"
                )
            }
            Log.i(TAG_STATE, "Subtitle pipeline stopped")
        }
    }

    fun release() {
        stop()
        activeAsrEngine.release()
    }

    private fun startInferConsumer() {
        inferConsumerJob = scope.launch(Dispatchers.Default) {
            for (task in inferChannel) {
                val isFinal = task is InferTask.Final
                val audioDurationMs = (task.pcmSnapshot.size * 1000L) / SAMPLE_RATE
                val segment = activeAsrEngine.transcribe(
                    pcm16kMono = task.pcmSnapshot,
                    segmentId = task.segmentId,
                    startTimeMs = task.startTimeMs,
                    endTimeMs = task.endTimeMs,
                    isFinalTrigger = isFinal
                )

                val endToEndLatencyMs = SystemClock.elapsedRealtime() - task.audioEntryTimestampMs
                val updatedSegment = segment.copy(latencyMs = endToEndLatencyMs)
                val rtf = if (audioDurationMs > 0L) {
                    segment.latencyMs.toFloat() / audioDurationMs.toFloat()
                } else {
                    0f
                }

                if (isFinal) {
                    val reason = (task as InferTask.Final).reason
                    Log.i(
                        TAG_PERF,
                        "FINAL committed id=${updatedSegment.id} reason=$reason " +
                            "e2eLatency=${endToEndLatencyMs}ms rtf=${"%.3f".format(rtf)} Backend=${updatedSegment.backendTag.label}"
                    )
                } else {
                    isDraftInFlight.set(false)
                    Log.d(
                        TAG_PERF,
                        "DRAFT emitted id=${updatedSegment.id} e2eLatency=${endToEndLatencyMs}ms Backend=${updatedSegment.backendTag.label}"
                    )
                }

                applySegmentToState(updatedSegment, rtf)
            }
        }
    }

    private suspend fun handleAudioChunk(chunk: AudioFrameChunk) {
        var taskToEnqueue: InferTask? = null

        bufferMutex.withLock {
            val incoming = chunk.pcmData
            totalCapturedSamples += incoming.size

            when (chunk.transition) {
                VadTransition.SPEECH_START -> {
                    if (!hasSpeechInWindow) {
                        windowSampleCount = 0
                        windowStartTotalSamples = totalCapturedSamples - incoming.size
                        currentActiveSegmentId = segmentIdGen.incrementAndGet()
                        hasSpeechInWindow = true
                        lastDraftDispatchMs = chunk.captureTimestampMs
                    }
                }

                VadTransition.SPEECH_END -> {
                    if (hasSpeechInWindow && windowSampleCount >= MIN_INFER_SAMPLES) {
                        val snapshot = windowBuffer.copyOf(windowSampleCount)
                        val startMs = samplesToCorrectedMs(windowStartTotalSamples)
                        val endMs = samplesToCorrectedMs(windowStartTotalSamples + windowSampleCount)
                        taskToEnqueue = InferTask.Final(
                            pcmSnapshot = snapshot,
                            segmentId = currentActiveSegmentId,
                            startTimeMs = startMs,
                            endTimeMs = endMs,
                            audioEntryTimestampMs = chunk.captureTimestampMs,
                            reason = "VAD_SPEECH_END"
                        )
                    }
                    windowSampleCount = 0
                    hasSpeechInWindow = false
                }

                VadTransition.NONE -> Unit
            }

            if (chunk.isSpeech || hasSpeechInWindow) {
                val copyLen = minOf(incoming.size, windowBuffer.size - windowSampleCount)
                if (copyLen > 0) {
                    incoming.copyInto(windowBuffer, destinationOffset = windowSampleCount, endIndex = copyLen)
                    windowSampleCount += copyLen
                }

                if (windowSampleCount >= MAX_WINDOW_SAMPLES) {
                    val snapshot = windowBuffer.copyOf(MAX_WINDOW_SAMPLES)
                    val startMs = samplesToCorrectedMs(windowStartTotalSamples)
                    val endMs = samplesToCorrectedMs(windowStartTotalSamples + MAX_WINDOW_SAMPLES)
                    val finalizedId = currentActiveSegmentId

                    val shiftFrom = MAX_WINDOW_SAMPLES - OVERLAP_SAMPLES
                    System.arraycopy(windowBuffer, shiftFrom, windowBuffer, 0, OVERLAP_SAMPLES)
                    windowSampleCount = OVERLAP_SAMPLES
                    windowStartTotalSamples += shiftFrom
                    currentActiveSegmentId = segmentIdGen.incrementAndGet()
                    lastDraftDispatchMs = chunk.captureTimestampMs

                    Log.i(TAG_STATE, "30s boundary split: finalizedId=$finalizedId -> nextId=$currentActiveSegmentId")

                    taskToEnqueue = InferTask.Final(
                        pcmSnapshot = snapshot,
                        segmentId = finalizedId,
                        startTimeMs = startMs,
                        endTimeMs = endMs,
                        audioEntryTimestampMs = chunk.captureTimestampMs,
                        reason = "30S_BOUNDARY_OVERLAP"
                    )
                } else if (
                    chunk.transition == VadTransition.NONE &&
                    hasSpeechInWindow &&
                    windowSampleCount >= MIN_INFER_SAMPLES &&
                    (chunk.captureTimestampMs - lastDraftDispatchMs >= DRAFT_INTERVAL_MS) &&
                    isDraftInFlight.compareAndSet(false, true)
                ) {
                    val snapshot = windowBuffer.copyOf(windowSampleCount)
                    val startMs = samplesToCorrectedMs(windowStartTotalSamples)
                    val endMs = samplesToCorrectedMs(windowStartTotalSamples + windowSampleCount)
                    lastDraftDispatchMs = chunk.captureTimestampMs

                    taskToEnqueue = InferTask.Draft(
                        pcmSnapshot = snapshot,
                        segmentId = currentActiveSegmentId,
                        startTimeMs = startMs,
                        endTimeMs = endMs,
                        audioEntryTimestampMs = chunk.captureTimestampMs
                    )
                }
            }

            val currentWindowSec = windowSampleCount.toFloat() / SAMPLE_RATE.toFloat()
            _uiState.update { state ->
                state.copy(
                    isSpeechActive = chunk.isSpeech,
                    latestRms = chunk.rmsEnergy,
                    activeWindowSec = currentWindowSec
                )
            }
        }

        taskToEnqueue?.let { task ->
            val sent = inferChannel.trySend(task).isSuccess
            if (!sent && task is InferTask.Draft) {
                isDraftInFlight.set(false)
            }
        }
    }

    private suspend fun flushRemainingAsFinal() {
        val flushTask: InferTask.Final? = bufferMutex.withLock {
            if (hasSpeechInWindow && windowSampleCount >= MIN_INFER_SAMPLES) {
                val snapshot = windowBuffer.copyOf(windowSampleCount)
                val startMs = samplesToCorrectedMs(windowStartTotalSamples)
                val endMs = samplesToCorrectedMs(windowStartTotalSamples + windowSampleCount)
                val segId = currentActiveSegmentId
                windowSampleCount = 0
                hasSpeechInWindow = false
                InferTask.Final(
                    pcmSnapshot = snapshot,
                    segmentId = segId,
                    startTimeMs = startMs,
                    endTimeMs = endMs,
                    audioEntryTimestampMs = SystemClock.elapsedRealtime(),
                    reason = "MANUAL_STOP_FLUSH"
                )
            } else {
                windowSampleCount = 0
                hasSpeechInWindow = false
                null
            }
        }

        if (flushTask != null) {
            inferChannel.trySend(flushTask)
        }
    }

    private fun applySegmentToState(incoming: SubtitleSegment, rtf: Float) {
        _uiState.update { state ->
            val currentList = state.segments.toMutableList()
            val existingIdx = currentList.indexOfFirst { it.id == incoming.id }

            if (existingIdx >= 0) {
                val existing = currentList[existingIdx]
                if (!existing.isFinal || incoming.isFinal) {
                    currentList[existingIdx] = incoming
                }
            } else {
                currentList.add(incoming)
            }

            state.copy(
                segments = currentList,
                lastLatencyMs = incoming.latencyMs,
                lastRtf = rtf,
                backendTag = incoming.backendTag
            )
        }
    }

    private fun resetWindowCounters() {
        windowSampleCount = 0
        windowStartTotalSamples = 0L
        totalCapturedSamples = 0L
        accumulatedDriftCorrectionMs = 0L
        hasSpeechInWindow = false
        lastDraftDispatchMs = 0L
        isDraftInFlight.set(false)
    }

    private fun samplesToMs(samples: Long): Long = (samples * 1000L) / SAMPLE_RATE

    private fun samplesToCorrectedMs(samples: Long): Long =
        (samplesToMs(samples) + accumulatedDriftCorrectionMs).coerceAtLeast(0L)
}
