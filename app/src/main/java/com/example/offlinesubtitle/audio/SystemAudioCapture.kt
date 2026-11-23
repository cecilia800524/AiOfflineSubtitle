package com.example.offlinesubtitle.audio

import android.annotation.SuppressLint
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.os.Build
import android.os.Process
import android.os.SystemClock
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.isActive
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.sqrt

class SystemAudioCapture {

    companion object {
        private const val TAG_VAD = "[ASR_VAD]"
        private const val TAG_SERVICE = "[ASR_SERVICE]"

        const val SAMPLE_RATE = 16_000
        const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        const val FRAME_SAMPLES = 512
        const val FRAME_BYTES = FRAME_SAMPLES * 2

        private const val SPEECH_RMS_THRESHOLD = 0.015f
        private const val HANGOVER_FRAMES = 15
        private const val ZERO_SIGNAL_WARN_FRAMES = 125
    }

    @Volatile
    private var activeRecorder: AudioRecord? = null

    fun captureFromSystemAudio(
        mediaProjection: MediaProjection,
        onZeroSignalWarning: (Boolean) -> Unit = {}
    ): Flow<AudioFrameChunk> = startInternalCapture(
        sourceTag = "SYSTEM_AUDIO",
        onZeroSignalWarning = onZeroSignalWarning
    ) { minBufBytes ->
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw UnsupportedOperationException("系統音訊擷取需要 Android 10 (API 29) 以上")
        }
        val playbackConfig = AudioPlaybackCaptureConfiguration.Builder(mediaProjection)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            .addMatchingUsage(AudioAttributes.USAGE_GAME)
            .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
            .build()

        AudioRecord.Builder()
            .setAudioFormat(buildAudioFormat())
            .setBufferSizeInBytes(maxOf(minBufBytes, FRAME_BYTES * 8))
            .setAudioPlaybackCaptureConfig(playbackConfig)
            .build()
    }

    @SuppressLint("MissingPermission")
    fun captureFromMicrophone(): Flow<AudioFrameChunk> = startInternalCapture(
        sourceTag = "MICROPHONE",
        onZeroSignalWarning = {}
    ) { minBufBytes ->
        AudioRecord.Builder()
            .setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION)
            .setAudioFormat(buildAudioFormat())
            .setBufferSizeInBytes(maxOf(minBufBytes, FRAME_BYTES * 8))
            .build()
    }

    @SuppressLint("MissingPermission")
    private fun startInternalCapture(
        sourceTag: String,
        onZeroSignalWarning: (Boolean) -> Unit,
        createRecorder: (minBufBytes: Int) -> AudioRecord
    ): Flow<AudioFrameChunk> = flow {
        Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)

        val minBufBytes = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        require(minBufBytes > 0) { "裝置不支援 16kHz Mono 16-bit PCM" }

        val recorder = createRecorder(minBufBytes)
        check(recorder.state == AudioRecord.STATE_INITIALIZED) {
            "$sourceTag AudioRecord 初始化失敗"
        }
        activeRecorder = recorder

        val byteBuf = ByteArray(FRAME_BYTES)
        var inSpeech = false
        var silenceFrames = 0
        var speechStartMs = 0L
        var consecutiveZeroFrames = 0
        var warnedDrm = false

        Log.i(TAG_SERVICE, "SystemAudioCapture started mode=$sourceTag")
        try {
            recorder.startRecording()
            while (currentCoroutineContext().isActive) {
                val readBytes = recorder.read(byteBuf, 0, FRAME_BYTES, AudioRecord.READ_BLOCKING)
                if (readBytes == FRAME_BYTES) {
                    val pcm = ShortArray(FRAME_SAMPLES)
                    ByteBuffer.wrap(byteBuf)
                        .order(ByteOrder.LITTLE_ENDIAN)
                        .asShortBuffer()
                        .get(pcm)

                    val nowMs = SystemClock.elapsedRealtime()
                    val rms = computeRms(pcm)

                    if (sourceTag == "SYSTEM_AUDIO") {
                        if (rms < 1e-6f) {
                            consecutiveZeroFrames++
                            if (consecutiveZeroFrames >= ZERO_SIGNAL_WARN_FRAMES && !warnedDrm) {
                                warnedDrm = true
                                onZeroSignalWarning(true)
                                Log.w(TAG_VAD, "SystemAudio 連續全零訊號，目標 App 可能受 DRM 或內錄限制")
                            }
                        } else {
                            if (warnedDrm) {
                                warnedDrm = false
                                onZeroSignalWarning(false)
                            }
                            consecutiveZeroFrames = 0
                        }
                    }

                    var transition = VadTransition.NONE
                    if (rms >= SPEECH_RMS_THRESHOLD) {
                        silenceFrames = 0
                        if (!inSpeech) {
                            inSpeech = true
                            speechStartMs = nowMs
                            transition = VadTransition.SPEECH_START
                            Log.d(TAG_VAD, "[$sourceTag] VAD SPEECH_START rms=${"%.4f".format(rms)}")
                        }
                    } else if (inSpeech) {
                        silenceFrames++
                        if (silenceFrames >= HANGOVER_FRAMES) {
                            inSpeech = false
                            silenceFrames = 0
                            transition = VadTransition.SPEECH_END
                            Log.d(TAG_VAD, "[$sourceTag] VAD SPEECH_END dur=${nowMs - speechStartMs}ms")
                        }
                    }

                    emit(
                        AudioFrameChunk(
                            pcmData = pcm,
                            rmsEnergy = rms,
                            isSpeech = inSpeech,
                            transition = transition,
                            captureTimestampMs = nowMs
                        )
                    )
                } else if (readBytes < 0) {
                    Log.e(TAG_VAD, "[$sourceTag] AudioRecord.read error=$readBytes")
                    break
                }
            }
        } finally {
            releaseRecorder(recorder)
            Log.i(TAG_SERVICE, "SystemAudioCapture stopped mode=$sourceTag")
        }
    }.flowOn(Dispatchers.IO)

    fun stop() {
        activeRecorder?.let { releaseRecorder(it) }
    }

    private fun releaseRecorder(recorder: AudioRecord) {
        runCatching {
            if (recorder.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                recorder.stop()
            }
            recorder.release()
        }
        if (activeRecorder === recorder) {
            activeRecorder = null
        }
    }

    private fun buildAudioFormat(): AudioFormat = AudioFormat.Builder()
        .setEncoding(AUDIO_FORMAT)
        .setSampleRate(SAMPLE_RATE)
        .setChannelMask(CHANNEL_CONFIG)
        .build()

    private fun computeRms(pcm: ShortArray): Float {
        var sumSq = 0.0
        for (s in pcm) {
            val norm = s / 32768.0
            sumSq += norm * norm
        }
        return sqrt(sumSq / pcm.size).toFloat()
    }
}
