package com.example.offlinesubtitle.asr

import android.content.Context
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.os.SystemClock
import android.provider.OpenableColumns
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.isActive
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.Locale
import kotlin.math.sqrt

data class FileTranscriptionReport(
    val fileName: String,
    val audioDurationMs: Long,
    val processingTimeMs: Long,
    val rtf: Float,
    val backendTag: BackendTag,
    val segments: List<SubtitleSegment>
)

class WavFileTranscriber(private val context: Context) {

    companion object {
        private const val TAG_PERF = "[ASR_PERF]"
        private const val TAG_VAD = "[ASR_VAD]"

        private const val TARGET_SAMPLE_RATE = 16_000
        private const val WINDOW_SAMPLES = 30 * TARGET_SAMPLE_RATE
        private const val OVERLAP_SAMPLES = 2 * TARGET_SAMPLE_RATE
        private const val STRIDE_SAMPLES = WINDOW_SAMPLES - OVERLAP_SAMPLES
        private const val SILENCE_RMS_THRESHOLD = 0.004f
    }

    suspend fun transcribeUri(
        uri: Uri,
        asrEngine: AsrEngine,
        onProgress: (Float) -> Unit = {}
    ): Result<FileTranscriptionReport> = withContext(Dispatchers.IO) {
        runCatching {
            val totalStartMs = SystemClock.elapsedRealtime()
            val fileName = resolveFileName(uri)

            val decodeStartMs = SystemClock.elapsedRealtime()
            val pcm16k = decodeTo16kMonoPcm(uri, fileName)
            val decodeCostMs = SystemClock.elapsedRealtime() - decodeStartMs
            require(pcm16k.isNotEmpty()) { "無法從檔案解析出有效音軌: $fileName" }

            val audioDurationMs = (pcm16k.size * 1000L) / TARGET_SAMPLE_RATE
            Log.i(
                TAG_PERF,
                "Decoded file=$fileName samples=${pcm16k.size} audioMs=$audioDurationMs decodeCost=${decodeCostMs}ms"
            )

            val segments = mutableListOf<SubtitleSegment>()
            var offset = 0
            var segId = 10_000L

            withContext(Dispatchers.Default) {
                while (offset < pcm16k.size && currentCoroutineContext().isActive) {
                    val end = minOf(offset + WINDOW_SAMPLES, pcm16k.size)
                    val chunk = pcm16k.copyOfRange(offset, end)
                    val startMs = (offset * 1000L) / TARGET_SAMPLE_RATE
                    val endMs = (end * 1000L) / TARGET_SAMPLE_RATE

                    val rms = computeRms(chunk)
                    if (rms >= SILENCE_RMS_THRESHOLD) {
                        val segment = asrEngine.transcribe(
                            pcm16kMono = chunk,
                            segmentId = segId++,
                            startTimeMs = startMs,
                            endTimeMs = endMs,
                            isFinalTrigger = true
                        )
                        segments.add(segment)
                    } else {
                        Log.d(TAG_VAD, "File chunk skipped (silence) range=${startMs}..${endMs}ms rms=${"%.4f".format(rms)}")
                    }

                    onProgress((end.toFloat() / pcm16k.size.toFloat()).coerceIn(0f, 1f))
                    if (end >= pcm16k.size) break
                    offset += STRIDE_SAMPLES
                }
            }

            val processingTimeMs = (SystemClock.elapsedRealtime() - totalStartMs).coerceAtLeast(1L)
            val rtf = if (audioDurationMs > 0L) {
                processingTimeMs.toFloat() / audioDurationMs.toFloat()
            } else {
                0f
            }

            Log.i(
                TAG_PERF,
                String.format(
                    Locale.US,
                    "FileTranscribe BENCHMARK file=%s Backend=%s audioMs=%d processMs=%d RTF=%.4f segments=%d",
                    fileName,
                    asrEngine.currentBackend.label,
                    audioDurationMs,
                    processingTimeMs,
                    rtf,
                    segments.size
                )
            )

            FileTranscriptionReport(
                fileName = fileName,
                audioDurationMs = audioDurationMs,
                processingTimeMs = processingTimeMs,
                rtf = rtf,
                backendTag = asrEngine.currentBackend,
                segments = segments
            )
        }
    }

    private fun decodeTo16kMonoPcm(uri: Uri, fileName: String): ShortArray {
        if (fileName.lowercase(Locale.US).endsWith(".wav")) {
            tryDecodeRawWav(uri)?.let { return it }
        }
        return decodeViaMediaExtractor(uri)
    }

    private fun tryDecodeRawWav(uri: Uri): ShortArray? {
        val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return null
        if (bytes.size < 44) return null
        val header = String(bytes, 0, 4, Charsets.US_ASCII)
        val wave = String(bytes, 8, 4, Charsets.US_ASCII)
        if (header != "RIFF" || wave != "WAVE") return null

        val bb = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        var pos = 12
        var audioFormat = 1
        var channels = 1
        var sampleRate = 16_000
        var bitsPerSample = 16
        var dataOffset = -1
        var dataSize = 0

        while (pos + 8 <= bytes.size) {
            val chunkId = String(bytes, pos, 4, Charsets.US_ASCII)
            val chunkSize = bb.getInt(pos + 4)
            val payloadPos = pos + 8
            if (chunkId == "fmt " && payloadPos + 16 <= bytes.size) {
                audioFormat = bb.getShort(payloadPos).toInt() and 0xFFFF
                channels = bb.getShort(payloadPos + 2).toInt() and 0xFFFF
                sampleRate = bb.getInt(payloadPos + 4)
                bitsPerSample = bb.getShort(payloadPos + 14).toInt() and 0xFFFF
            } else if (chunkId == "data") {
                dataOffset = payloadPos
                dataSize = minOf(chunkSize, bytes.size - payloadPos)
                break
            }
            pos = payloadPos + chunkSize + (chunkSize and 1)
        }

        if (audioFormat != 1 || bitsPerSample != 16 || dataOffset < 0 || dataSize <= 0) return null

        val totalFrames = dataSize / (2 * channels)
        val monoSrc = ShortArray(totalFrames)
        for (i in 0 until totalFrames) {
            var sum = 0
            for (ch in 0 until channels) {
                sum += bb.getShort(dataOffset + (i * channels + ch) * 2).toInt()
            }
            monoSrc[i] = (sum / channels).toShort()
        }
        return resampleLinear(monoSrc, sampleRate, TARGET_SAMPLE_RATE)
    }

    private fun decodeViaMediaExtractor(uri: Uri): ShortArray {
        val extractor = MediaExtractor()
        extractor.setDataSource(context, uri, null)

        var audioTrackIndex = -1
        var trackFormat: MediaFormat? = null
        for (i in 0 until extractor.trackCount) {
            val fmt = extractor.getTrackFormat(i)
            val mime = fmt.getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith("audio/")) {
                audioTrackIndex = i
                trackFormat = fmt
                break
            }
        }
        require(audioTrackIndex >= 0 && trackFormat != null) { "檔案中未包含音訊軌道" }
        extractor.selectTrack(audioTrackIndex)

        val mime = trackFormat.getString(MediaFormat.KEY_MIME)!!
        var srcSampleRate = trackFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        var srcChannels = trackFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        var pcmEncoding = AudioFormat.ENCODING_PCM_16BIT

        val codec = MediaCodec.createDecoderByType(mime)
        codec.configure(trackFormat, null, null, 0)
        codec.start()

        val pcmBufferOut = ByteArrayOutputStream()
        val bufferInfo = MediaCodec.BufferInfo()
        var sawInputEos = false
        var sawOutputEos = false

        try {
            while (!sawOutputEos) {
                if (!sawInputEos) {
                    val inIdx = codec.dequeueInputBuffer(10_000L)
                    if (inIdx >= 0) {
                        val inBuf = codec.getInputBuffer(inIdx)!!
                        val sampleSize = extractor.readSampleData(inBuf, 0)
                        if (sampleSize < 0) {
                            codec.queueInputBuffer(inIdx, 0, 0, 0L, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            sawInputEos = true
                        } else {
                            codec.queueInputBuffer(inIdx, 0, sampleSize, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }

                val outIdx = codec.dequeueOutputBuffer(bufferInfo, 10_000L)
                when {
                    outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val outFmt = codec.outputFormat
                        if (outFmt.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                            srcSampleRate = outFmt.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        }
                        if (outFmt.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                            srcChannels = outFmt.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        }
                        if (outFmt.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
                            pcmEncoding = outFmt.getInteger(MediaFormat.KEY_PCM_ENCODING)
                        }
                    }
                    outIdx >= 0 -> {
                        val outBuf = codec.getOutputBuffer(outIdx)
                        if (outBuf != null && bufferInfo.size > 0) {
                            outBuf.position(bufferInfo.offset)
                            outBuf.limit(bufferInfo.offset + bufferInfo.size)
                            val chunk = ByteArray(bufferInfo.size)
                            outBuf.get(chunk)
                            pcmBufferOut.write(chunk)
                        }
                        codec.releaseOutputBuffer(outIdx, false)
                        if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                            sawOutputEos = true
                        }
                    }
                }
            }
        } finally {
            runCatching { codec.stop() }
            runCatching { codec.release() }
            runCatching { extractor.release() }
        }

        val rawBytes = pcmBufferOut.toByteArray()
        val monoSrc = convertRawPcmToMonoShorts(rawBytes, srcChannels.coerceAtLeast(1), pcmEncoding)
        return resampleLinear(monoSrc, srcSampleRate, TARGET_SAMPLE_RATE)
    }

    private fun convertRawPcmToMonoShorts(
        rawBytes: ByteArray,
        channels: Int,
        pcmEncoding: Int
    ): ShortArray {
        val bb = ByteBuffer.wrap(rawBytes).order(ByteOrder.LITTLE_ENDIAN)
        return if (pcmEncoding == AudioFormat.ENCODING_PCM_FLOAT) {
            val totalFloats = rawBytes.size / 4
            val totalFrames = totalFloats / channels
            ShortArray(totalFrames) { frame ->
                var sum = 0f
                for (ch in 0 until channels) {
                    sum += bb.getFloat((frame * channels + ch) * 4)
                }
                ((sum / channels).coerceIn(-1f, 1f) * Short.MAX_VALUE).toInt().toShort()
            }
        } else {
            val totalShorts = rawBytes.size / 2
            val totalFrames = totalShorts / channels
            ShortArray(totalFrames) { frame ->
                var sum = 0
                for (ch in 0 until channels) {
                    sum += bb.getShort((frame * channels + ch) * 2).toInt()
                }
                (sum / channels).toShort()
            }
        }
    }

    private fun resampleLinear(src: ShortArray, srcRate: Int, dstRate: Int): ShortArray {
        if (src.isEmpty() || srcRate == dstRate) return src
        val ratio = srcRate.toDouble() / dstRate.toDouble()
        val dstLen = (src.size / ratio).toInt().coerceAtLeast(1)
        return ShortArray(dstLen) { i ->
            val srcPos = i * ratio
            val idx0 = srcPos.toInt().coerceIn(0, src.lastIndex)
            val idx1 = (idx0 + 1).coerceIn(0, src.lastIndex)
            val frac = srcPos - idx0
            ((src[idx0] * (1.0 - frac)) + (src[idx1] * frac)).toInt().toShort()
        }
    }

    private fun computeRms(pcm: ShortArray): Float {
        var sumSq = 0.0
        for (s in pcm) {
            val norm = s / 32768.0
            sumSq += norm * norm
        }
        return sqrt(sumSq / pcm.size).toFloat()
    }

    private fun resolveFileName(uri: Uri): String {
        context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) return cursor.getString(idx)
                }
            }
        return uri.lastPathSegment ?: "audio_sample.wav"
    }
}
