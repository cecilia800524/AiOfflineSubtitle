package com.example.offlinesubtitle.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BugReport
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.offlinesubtitle.asr.SubtitleSegment
import com.example.offlinesubtitle.export.SubtitleExportFormat
import java.util.Locale

@Composable
fun TranscriptEditorScreen(
    segments: List<SubtitleSegment>,
    exportStatusMessage: String?,
    onEditSegment: (segmentId: Long, newText: String) -> Unit,
    onExportAndSave: (SubtitleExportFormat) -> Unit,
    onExportAndShare: (SubtitleExportFormat) -> Unit,
    onLoadBuiltInTestMode: () -> Unit
) {
    var searchQuery by remember { mutableStateOf("") }
    var editingSegment by remember { mutableStateOf<SubtitleSegment?>(null) }
    var editBufferText by remember { mutableStateOf("") }
    var selectedFormat by remember { mutableStateOf(SubtitleExportFormat.SRT) }

    val filteredSegments = remember(segments, searchQuery) {
        if (searchQuery.isBlank()) {
            segments
        } else {
            segments.filter { it.text.contains(searchQuery, ignoreCase = true) }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                placeholder = { Text("搜尋字幕關鍵字...") },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                trailingIcon = {
                    if (searchQuery.isNotEmpty()) {
                        IconButton(onClick = { searchQuery = "" }) {
                            Icon(Icons.Default.Clear, contentDescription = "清除搜尋")
                        }
                    }
                },
                singleLine = true,
                modifier = Modifier.weight(1f)
            )

            OutlinedButton(
                onClick = onLoadBuiltInTestMode,
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 14.dp)
            ) {
                Icon(Icons.Default.BugReport, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text("測試資料", style = MaterialTheme.typography.labelMedium)
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "格式：",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    SubtitleExportFormat.entries.forEach { fmt ->
                        val selected = selectedFormat == fmt
                        if (selected) {
                            Button(
                                onClick = { selectedFormat = fmt },
                                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp),
                                modifier = Modifier.height(34.dp)
                            ) {
                                Text(fmt.label, style = MaterialTheme.typography.labelMedium)
                            }
                        } else {
                            OutlinedButton(
                                onClick = { selectedFormat = fmt },
                                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp),
                                modifier = Modifier.height(34.dp)
                            ) {
                                Text(fmt.label, style = MaterialTheme.typography.labelMedium)
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedButton(
                        onClick = { onExportAndSave(selectedFormat) },
                        enabled = segments.isNotEmpty(),
                        modifier = Modifier.weight(1f)
                    ) {
                        Icon(Icons.Default.Download, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("存至 Downloads")
                    }

                    Button(
                        onClick = { onExportAndShare(selectedFormat) },
                        enabled = segments.isNotEmpty(),
                        modifier = Modifier.weight(1f)
                    ) {
                        Icon(Icons.Default.Share, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("匯出並分享")
                    }
                }

                if (!exportStatusMessage.isNullOrBlank()) {
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = exportStatusMessage,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        if (filteredSegments.isEmpty()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = if (segments.isEmpty()) "尚無轉錄字幕，請先錄音、匯入音檔或點擊「測試資料」" else "查無符合「$searchQuery」的字幕",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(
                    items = filteredSegments,
                    key = { it.id }
                ) { seg ->
                    Card(
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                editingSegment = seg
                                editBufferText = seg.text
                            }
                    ) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "#${seg.id}  ${formatEditorMs(seg.startTimeMs)} → ${formatEditorMs(seg.endTimeMs)}",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                Icon(
                                    imageVector = Icons.Default.Edit,
                                    contentDescription = "編輯",
                                    tint = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = highlightKeyword(seg.text, searchQuery),
                                style = MaterialTheme.typography.bodyLarge
                            )
                        }
                    }
                }
            }
        }
    }

    editingSegment?.let { target ->
        AlertDialog(
            onDismissRequest = { editingSegment = null },
            title = { Text("編輯第 #${target.id} 句字幕") },
            text = {
                OutlinedTextField(
                    value = editBufferText,
                    onValueChange = { editBufferText = it },
                    minLines = 3,
                    maxLines = 6,
                    modifier = Modifier.fillMaxWidth()
                )
            },
            confirmButton = {
                Button(
                    onClick = {
                        onEditSegment(target.id, editBufferText)
                        editingSegment = null
                    }
                ) {
                    Text("儲存修改")
                }
            },
            dismissButton = {
                TextButton(onClick = { editingSegment = null }) {
                    Text("取消")
                }
            }
        )
    }
}

private fun highlightKeyword(text: String, query: String): AnnotatedString {
    if (query.isBlank()) return AnnotatedString(text)
    return buildAnnotatedString {
        append(text)
        var startIndex = 0
        while (startIndex < text.length) {
            val found = text.indexOf(query, startIndex = startIndex, ignoreCase = true)
            if (found < 0) break
            addStyle(
                style = SpanStyle(
                    background = Color(0xFFFFEB3B),
                    color = Color.Black,
                    fontWeight = FontWeight.Bold
                ),
                start = found,
                end = found + query.length
            )
            startIndex = found + query.length
        }
    }
}

private fun formatEditorMs(ms: Long): String {
    val totalSec = ms / 1000L
    val min = totalSec / 60L
    val sec = totalSec % 60L
    val tenth = (ms % 1000L) / 100L
    return String.format(Locale.US, "%02d:%02d.%d", min, sec, tenth)
}
