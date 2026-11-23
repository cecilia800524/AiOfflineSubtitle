package com.example.offlinesubtitle.export

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import androidx.core.content.FileProvider
import com.example.offlinesubtitle.asr.SubtitleSegment
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

enum class SubtitleExportFormat(
    val extension: String,
    val mimeType: String,
    val label: String
) {
    SRT("srt", "application/x-subrip", "SRT"),
    VTT("vtt", "text/vtt", "VTT"),
    TXT("txt", "text/plain", "TXT")
}

data class ExportResult(
    val fileName: String,
    val shareUri: Uri,
    val downloadsUri: Uri?,
    val segmentCount: Int,
    val overlapsFixed: Int
)

class SubtitleExporter(private val context: Context) {

    companion object {
        private const val TAG_STATE = "[ASR_STATE]"
        private const val MIN_SEGMENT_DURATION_MS = 300L
    }

    data class ValidationOutput(
        val normalizedSegments: List<SubtitleSegment>,
        val overlapsFixed: Int,
        val durationsFixed: Int
    )

    fun normalizeTimeline(rawSegments: List<SubtitleSegment>): ValidationOutput {
        val sorted = rawSegments
            .filter { it.text.isNotBlank() }
            .sortedWith(compareBy<SubtitleSegment> { it.startTimeMs }.thenBy { it.id })

        val result = ArrayList<SubtitleSegment>(sorted.size)
        var overlapsFixed = 0
        var durationsFixed = 0

        for (seg in sorted) {
            var startMs = seg.startTimeMs
            var endMs = seg.endTimeMs

            if (startMs < 0L) {
                startMs = 0L
                durationsFixed++
            }

            val prev = result.lastOrNull()
            if (prev != null && startMs < prev.endTimeMs) {
                startMs = prev.endTimeMs
                overlapsFixed++
            }

            if (endMs <= startMs) {
                endMs = startMs + MIN_SEGMENT_DURATION_MS
                durationsFixed++
            }

            result.add(
                seg.copy(
                    text = seg.text.trim(),
                    startTimeMs = startMs,
                    endTimeMs = endMs
                )
            )
        }

        Log.i(
            TAG_STATE,
            "Timeline validated: count=${result.size}, overlapsFixed=$overlapsFixed, durationsFixed=$durationsFixed"
        )
        return ValidationOutput(result, overlapsFixed, durationsFixed)
    }

    fun formatContent(
        segments: List<SubtitleSegment>,
        format: SubtitleExportFormat
    ): Pair<String, ValidationOutput> {
        val validation = normalizeTimeline(segments)
        val normalized = validation.normalizedSegments

        val text = when (format) {
            SubtitleExportFormat.SRT -> buildSrt(normalized)
            SubtitleExportFormat.VTT -> buildVtt(normalized)
            SubtitleExportFormat.TXT -> buildTxt(normalized)
        }
        return text to validation
    }

    suspend fun export(
        segments: List<SubtitleSegment>,
        format: SubtitleExportFormat,
        saveToDownloads: Boolean = true
    ): Result<ExportResult> = withContext(Dispatchers.IO) {
        runCatching {
            require(segments.isNotEmpty()) { "目前沒有可匯出的字幕內容" }

            val (content, validation) = formatContent(segments, format)
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            val fileName = "subtitle_$timestamp.${format.extension}"

            val exportDir = File(context.cacheDir, "exports").apply { mkdirs() }
            val cacheFile = File(exportDir, fileName)
            cacheFile.writeText(content, Charsets.UTF_8)
            val shareUri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                cacheFile
            )

            val downloadsUri = if (saveToDownloads) {
                saveFileToDownloads(fileName, format.mimeType, content)
            } else {
                null
            }

            ExportResult(
                fileName = fileName,
                shareUri = shareUri,
                downloadsUri = downloadsUri,
                segmentCount = validation.normalizedSegments.size,
                overlapsFixed = validation.overlapsFixed
            )
        }
    }

    private fun saveFileToDownloads(fileName: String, mimeType: String, utf8Content: String): Uri? {
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, mimeType)
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val resolver = context.contentResolver
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: return null

        resolver.openOutputStream(uri)?.use { out ->
            out.write(utf8Content.toByteArray(Charsets.UTF_8))
        }

        values.clear()
        values.put(MediaStore.Downloads.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
        return uri
    }

    private fun buildSrt(segments: List<SubtitleSegment>): String {
        val sb = StringBuilder()
        segments.forEachIndexed { idx, seg ->
            sb.append(idx + 1).append('\n')
            sb.append(formatSrtTime(seg.startTimeMs))
                .append(" --> ")
                .append(formatSrtTime(seg.endTimeMs))
                .append('\n')
            sb.append(seg.text).append("\n\n")
        }
        return sb.toString()
    }

    private fun buildVtt(segments: List<SubtitleSegment>): String {
        val sb = StringBuilder("WEBVTT\n\n")
        segments.forEachIndexed { idx, seg ->
            sb.append(idx + 1).append('\n')
            sb.append(formatVttTime(seg.startTimeMs))
                .append(" --> ")
                .append(formatVttTime(seg.endTimeMs))
                .append('\n')
            sb.append(seg.text).append("\n\n")
        }
        return sb.toString()
    }

    private fun buildTxt(segments: List<SubtitleSegment>): String {
        val sb = StringBuilder()
        segments.forEach { seg ->
            sb.append('[')
                .append(formatShortTime(seg.startTimeMs))
                .append("] ")
                .append(seg.text)
                .append('\n')
        }
        return sb.toString()
    }

    private fun formatSrtTime(ms: Long): String {
        val h = ms / 3_600_000L
        val m = (ms % 3_600_000L) / 60_000L
        val s = (ms % 60_000L) / 1_000L
        val milli = ms % 1_000L
        return String.format(Locale.US, "%02d:%02d:%02d,%03d", h, m, s, milli)
    }

    private fun formatVttTime(ms: Long): String {
        val h = ms / 3_600_000L
        val m = (ms % 3_600_000L) / 60_000L
        val s = (ms % 60_000L) / 1_000L
        val milli = ms % 1_000L
        return String.format(Locale.US, "%02d:%02d:%02d.%03d", h, m, s, milli)
    }

    private fun formatShortTime(ms: Long): String {
        val m = ms / 60_000L
        val s = (ms % 60_000L) / 1_000L
        val tenth = (ms % 1_000L) / 100L
        return String.format(Locale.US, "%02d:%02d.%d", m, s, tenth)
    }
}
