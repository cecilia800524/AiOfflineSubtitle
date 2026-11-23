package com.example.offlinesubtitle.audio

import android.media.projection.MediaProjection
import android.os.SystemClock
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.isActive
import kotlin.math.PI
import kotlin.math.sin
import kotlin.math.sqrt

enum class AudioInputSource(val label: String) {
    MICROPHONE("麥克風"),
    SYSTEM_AUDIO("系統音訊"),
    SIMULATED_PCM("模擬音訊")
}

enum class VadTransition {
    NONE,
    SPEECH_START,
    SPEECH_END
}

data class AudioFrameChunk(
    val pcmData: ShortArray,
    val rmsEnergy: Float,
    val isSpeech: Boolean,
    val transition: VadTransition,
    val captureTimestampMs: Long
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is AudioFrameChunk) return false
        return captureTimestampMs == other.captureTimestampMs &&
            isSpeech == other.isSpeech &&
            transition == other.transition &&
            pcmData.contentEquals(other.pcmData)
    }

    override fun hashCode(): Int {
        var result = pcmData.contentHashCode()
        result = 31 * result + isSpeech.hashCode()
        result = 31 * result + transition.hashCode()
        result = 31 * result + captureTimestampMs.hashCode()
        return result
    }
}

class AudioCaptureManager {

    companion object {
        private const val TAG_VAD = "[ASR_VAD]"

        const val SAMPLE_RATE = 16_000
        const val FRAME_SAMPLES = 512
        const val FRAME_DURATION_MS = 32L

        private const val SPEECH_RMS_THRESHOLD = 0.015f
        private const val HANGOVER_FRAMES = 15
    }

    private val systemAudioCapture = SystemAudioCapture()

    fun startCapture(
        source: AudioInputSource,
        mediaProjection: MediaProjection? = null,
        onSystemZeroSignalWarning: (Boolean) -> Unit = {}
    ): Flow<AudioFrameChunk> = when (source) {
        AudioInputSource.MICROPHONE -> systemAudioCapture.captureFromMicrophone()
        AudioInputSource.SYSTEM_AUDIO -> {
            val projection = requireNotNull(mediaProjection) {
                "系統音訊模式必須先取得 MediaProjection 授權"
            }
            systemAudioCapture.captureFromSystemAudio(projection, onSystemZeroSignalWarning)
        }
        AudioInputSource.SIMULATED_PCM -> captureSimulatedAudio()
    }

    private fun captureSimulatedAudio(): Flow<AudioFrameChunk> = flow {
        var inSpeech = false
        var silenceFrames = 0
        var frameIndex = 0L
        var phase = 0.0

        Log.i(TAG_VAD, "Simulated PCM capture started (16kHz Mono)")
        try {
            while (currentCoroutineContext().isActive) {
                val loopMs = (frameIndex * FRAME_DURATION_MS) % 7_000L
                val isSpeakingPhase = loopMs < 5_500L

                val pcm = ShortArray(FRAME_SAMPLES) { idx ->
                    if (isSpeakingPhase) {
                        val freq = 240.0 + 90.0 * sin(frameIndex * 0.15)
                        val sample = sin(phase + 2.0 * PI * freq * idx / SAMPLE_RATE) * 0.28
                        (sample * Short.MAX_VALUE).toInt().toShort()
                    } else {
                        ((idx % 7 - 3) * 8).toShort()
                    }
                }
                if (isSpeakingPhase) {
                    phase += 2.0 * PI * 240.0 * FRAME_SAMPLES / SAMPLE_RATE
                }

                val rms = computeRms(pcm)
                val nowMs = SystemClock.elapsedRealtime()
                var transition = VadTransition.NONE
                if (rms >= SPEECH_RMS_THRESHOLD) {
                    silenceFrames = 0
                    if (!inSpeech) {
                        inSpeech = true
                        transition = VadTransition.SPEECH_START
                        Log.d(TAG_VAD, "[SIM] VAD SPEECH_START rms=${"%.4f".format(rms)}")
                    }
                } else if (inSpeech) {
                    silenceFrames++
                    if (silenceFrames >= HANGOVER_FRAMES) {
                        inSpeech = false
                        silenceFrames = 0
                        transition = VadTransition.SPEECH_END
                        Log.d(TAG_VAD, "[SIM] VAD SPEECH_END")
                    }
                }

                emit(AudioFrameChunk(pcm, rms, inSpeech, transition, nowMs))
                frameIndex++
                delay(FRAME_DURATION_MS)
            }
        } finally {
            Log.i(TAG_VAD, "Simulated PCM capture stopped")
        }
    }.flowOn(Dispatchers.IO)

    fun stop() {
        systemAudioCapture.stop()
    }

    private fun computeRms(pcm: ShortArray): Float {
        var sumSq = 0.0
        for (s in pcm) {
            val norm = s / 32768.0
            sumSq += norm * norm
        }
        return sqrt(sumSq / pcm.size).toFloat()
    }
}
