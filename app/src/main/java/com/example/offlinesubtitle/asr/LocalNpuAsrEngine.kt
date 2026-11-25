package com.example.offlinesubtitle.asr

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtException
import ai.onnxruntime.OrtSession
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.provider.DocumentsContract
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileNotFoundException
import java.nio.FloatBuffer
import java.nio.LongBuffer
import java.util.Locale
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.sin

/**
 * 模型配置檔：
 * 預設 WHISPER_TINY_QNN -> getExternalFilesDir(null)/models/whisper-tiny
 */
enum class LocalModelProfile(
    val dirName: String,
    val displayName: String
) {
    WHISPER_TINY_QNN("whisper-tiny", "Whisper Tiny (QNN NPU)"),
    WHISPER_SMALL_QNN("whisper-small", "Whisper Small (本地 NPU)")
}

data class ModelLocationStatus(
    val activePath: String,
    val isCustomPath: Boolean,
    val directoryExists: Boolean,
    val hasEncoderOnnx: Boolean,
    val diskUsageMb: Double,
    val errorMessage: String?
)

class LocalNpuAsrEngine(
    private val context: Context,
    private var profile: LocalModelProfile = LocalModelProfile.WHISPER_TINY_QNN
) : AsrEngine {

    companion object {
        private const val TAG_PERF = "[ASR_PERF]"
        private const val TAG_STATE = "[ASR_STATE]"

        private const val PREFS_NAME = "offline_subtitle_prefs"
        const val KEY_CUSTOM_MODEL_PATH = "custom_model_path"

        private const val SAMPLE_RATE = 16_000
        private const val MAX_SAMPLES = 30 * SAMPLE_RATE
        private const val N_MELS = 80
        private const val MEL_FRAMES = 3000
        private const val MAX_DECODE_TOKENS = 128

        private const val DEFAULT_SOT = 50258
        private const val DEFAULT_LANG_ZH = 50260
        private const val DEFAULT_TASK_TRANSCRIBE = 50359
        private const val DEFAULT_NO_TIMESTAMPS = 50363
        private const val DEFAULT_EOT = 50257
    }

    private data class SafScanResult(
        val exists: Boolean,
        val totalBytes: Long,
        val encoderDocId: String?,
        val decoderDocId: String?,
        val qnnEncoderDocId: String?,
        val qnnDecoderDocId: String?,
        val vocabDocId: String?
    )

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val ortEnv: OrtEnvironment = OrtEnvironment.getEnvironment()
    private val inferMutex = Mutex()
    private val melExtractor = WhisperLogMelExtractor()
    private val unicodeToByte: Map<Char, Byte> = buildWhisperUnicodeToByteMap()

    private var encoderSession: OrtSession? = null
    private var decoderSession: OrtSession? = null
    private var idToToken: Map<Int, String> = emptyMap()
    private var eotTokenId: Int = DEFAULT_EOT

    @Volatile
    private var preferNpu: Boolean = true

    @Volatile
    private var activeBackend: BackendTag = BackendTag.QNN_NPU

    @Volatile
    var isLoaded: Boolean = false
        private set

    override val currentBackend: BackendTag
        get() = activeBackend

    init {
        ensureDefaultModelDirectories()
    }

    /**
     * 預設路徑：getExternalFilesDir(null)/models/whisper-tiny
     */
    fun getDefaultModelDir(): File {
        val externalRoot = context.getExternalFilesDir(null) ?: context.filesDir
        return File(externalRoot, "models/${profile.dirName}").apply {
            if (!exists()) mkdirs()
        }
    }

    fun getCustomModelPath(): String? {
        return prefs.getString(KEY_CUSTOM_MODEL_PATH, null)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
    }

    fun getEffectiveModelPath(): String {
        return getCustomModelPath() ?: getDefaultModelDir().absolutePath
    }

    fun setCustomModelPath(rawPath: String) {
        val trimmed = rawPath.trim()
        if (trimmed.isEmpty()) {
            resetCustomModelPath()
        } else {
            prefs.edit().putString(KEY_CUSTOM_MODEL_PATH, trimmed).apply()
            Log.i(TAG_STATE, "Saved custom_model_path=$trimmed")
        }
    }

    fun resetCustomModelPath() {
        prefs.edit().remove(KEY_CUSTOM_MODEL_PATH).apply()
        ensureDefaultModelDirectories()
        Log.i(TAG_STATE, "Cleared custom_model_path, reverted to default=${getDefaultModelDir().absolutePath}")
    }

    private fun ensureDefaultModelDirectories() {
        runCatching {
            val externalRoot = context.getExternalFilesDir(null) ?: context.filesDir
            val modelsRoot = File(externalRoot, "models").apply { if (!exists()) mkdirs() }
            LocalModelProfile.entries.forEach { p ->
                val dir = File(modelsRoot, p.dirName)
                if (!dir.exists()) dir.mkdirs()
            }
        }
    }

    /**
     * 優先讀取 SharedPreferences 的 custom_model_path，無自訂則讀取預設目錄，
     * 並檢查目錄存在性、encoder.onnx 存在性及磁碟空間用量 (MB)。
     */
    fun inspectModelLocation(): ModelLocationStatus {
        val customPath = getCustomModelPath()
        val effectivePath = customPath ?: getDefaultModelDir().absolutePath

        if (effectivePath.startsWith("content://")) {
            val safScan = scanSafTree(Uri.parse(effectivePath))
            val hasEncoder = safScan.exists && (safScan.encoderDocId != null || safScan.qnnEncoderDocId != null)
            val diskMb = safScan.totalBytes / (1024.0 * 1024.0)
            val err = if (!safScan.exists || !hasEncoder) "找不到 encoder.onnx" else null
            return ModelLocationStatus(
                activePath = effectivePath,
                isCustomPath = true,
                directoryExists = safScan.exists,
                hasEncoderOnnx = hasEncoder,
                diskUsageMb = diskMb,
                errorMessage = err
            )
        }

        val dir = resolveFileDirectory(effectivePath)
        val dirExists = dir.exists() && dir.isDirectory
        val hasEncoder = dirExists && (
            File(dir, "encoder.onnx").exists() ||
                File(dir, "encoder_qnn_ctx.onnx").exists()
            )
        val diskMb = if (dirExists) {
            dir.walkTopDown().filter { it.isFile }.sumOf { it.length() } / (1024.0 * 1024.0)
        } else {
            0.0
        }
        val err = if (!dirExists || !hasEncoder) "找不到 encoder.onnx" else null
        return ModelLocationStatus(
            activePath = dir.absolutePath,
            isCustomPath = customPath != null,
            directoryExists = dirExists,
            hasEncoderOnnx = hasEncoder,
            diskUsageMb = diskMb,
            errorMessage = err
        )
    }

    fun calculateModelsDiskUsageMb(): Double = inspectModelLocation().diskUsageMb

    fun setProfile(newProfile: LocalModelProfile) {
        profile = newProfile
        ensureDefaultModelDirectories()
    }

    fun getProfile(): LocalModelProfile = profile

    override fun setBackendMode(backendTag: BackendTag) {
        preferNpu = (backendTag == BackendTag.QNN_NPU)
        Log.i(TAG_PERF, "LocalNpuAsrEngine preference updated -> preferNpu=$preferNpu")
    }

    override suspend fun initialize(): Result<Unit> = withContext(Dispatchers.IO) {
        inferMutex.withLock {
            releaseInternal()

            val effectivePath = getEffectiveModelPath()
            val resolvedDir: File = if (effectivePath.startsWith("content://")) {
                prepareSafModelsIntoCache(Uri.parse(effectivePath)).getOrElse { err ->
                    return@withContext Result.failure(err)
                }
            } else {
                resolveFileDirectory(effectivePath)
            }

            if (!resolvedDir.exists() || !resolvedDir.isDirectory) {
                val msg = "找不到 encoder.onnx (${resolvedDir.absolutePath})"
                Log.w(TAG_STATE, msg)
                return@withContext Result.failure(FileNotFoundException("找不到 encoder.onnx"))
            }

            val qnnEncoderCtx = File(resolvedDir, "encoder_qnn_ctx.onnx")
            val qnnDecoderCtx = File(resolvedDir, "decoder_qnn_ctx.onnx")
            val stdEncoder = File(resolvedDir, "encoder.onnx")
            val stdDecoder = File(resolvedDir, "decoder.onnx")

            val encFile = when {
                preferNpu && qnnEncoderCtx.exists() -> qnnEncoderCtx
                stdEncoder.exists() -> stdEncoder
                qnnEncoderCtx.exists() -> qnnEncoderCtx
                else -> null
            }
            val decFile = when {
                preferNpu && qnnDecoderCtx.exists() -> qnnDecoderCtx
                stdDecoder.exists() -> stdDecoder
                qnnDecoderCtx.exists() -> qnnDecoderCtx
                else -> null
            }

            if (encFile == null || decFile == null) {
                val msg = if (encFile == null) "找不到 encoder.onnx" else "找不到 decoder.onnx"
                Log.w(TAG_STATE, "$msg at ${resolvedDir.absolutePath}")
                return@withContext Result.failure(FileNotFoundException(msg))
            }

            val loadStart = SystemClock.elapsedRealtime()
            val numThreads = Runtime.getRuntime().availableProcessors().coerceIn(2, 4)

            var loadedWithQnn = false
            if (preferNpu && isQnnHtpSupported()) {
                try {
                    val qnnOpts = createSessionOptions(useQnnNpu = true, numThreads = numThreads)
                    encoderSession = ortEnv.createSession(encFile.absolutePath, qnnOpts)
                    decoderSession = ortEnv.createSession(decFile.absolutePath, qnnOpts)
                    qnnOpts.close()
                    activeBackend = BackendTag.QNN_NPU
                    loadedWithQnn = true
                    Log.i(TAG_PERF, "Backend=QNN_NPU (loaded ${encFile.absolutePath}, threads=$numThreads)")
                } catch (t: Throwable) {
                    Log.w(TAG_PERF, "QNN EP init failed (${t.message}), falling back to CPU_FALLBACK")
                    releaseInternal()
                }
            }

            if (!loadedWithQnn) {
                try {
                    val cpuEnc = stdEncoder.takeIf { it.exists() } ?: encFile
                    val cpuDec = stdDecoder.takeIf { it.exists() } ?: decFile
                    val cpuOpts = createSessionOptions(useQnnNpu = false, numThreads = numThreads)
                    encoderSession = ortEnv.createSession(cpuEnc.absolutePath, cpuOpts)
                    decoderSession = ortEnv.createSession(cpuDec.absolutePath, cpuOpts)
                    cpuOpts.close()
                    activeBackend = BackendTag.CPU_FALLBACK
                    Log.i(TAG_PERF, "Backend=CPU_FALLBACK (loaded ${cpuEnc.absolutePath}, intraOpThreads=$numThreads)")
                } catch (e: OrtException) {
                    releaseInternal()
                    return@withContext Result.failure(e)
                }
            }

            loadTokenizerIfPresent(resolvedDir)
            isLoaded = true
            val loadCostMs = SystemClock.elapsedRealtime() - loadStart
            Log.i(
                TAG_PERF,
                "Model loaded path=${effectivePath} Backend=${activeBackend.label} " +
                    "loadTime=${loadCostMs}ms diskUsage=${"%.2f".format(calculateModelsDiskUsageMb())}MB"
            )
            Result.success(Unit)
        }
    }

    override suspend fun transcribe(
        pcm16kMono: ShortArray,
        segmentId: Long,
        startTimeMs: Long,
        endTimeMs: Long,
        isFinalTrigger: Boolean
    ): SubtitleSegment = withContext(Dispatchers.Default) {
        inferMutex.withLock {
            val enc = checkNotNull(encoderSession) { "LocalNpuAsrEngine 尚未載入模型" }
            val dec = checkNotNull(decoderSession) { "LocalNpuAsrEngine 尚未載入模型" }

            val inferStart = SystemClock.elapsedRealtime()
            val audioDurationMs = (pcm16kMono.size * 1000L) / SAMPLE_RATE

            val paddedFloat = FloatArray(MAX_SAMPLES)
            val copySamples = minOf(pcm16kMono.size, MAX_SAMPLES)
            for (i in 0 until copySamples) {
                paddedFloat[i] = pcm16kMono[i] / 32768.0f
            }
            val melFeatures = melExtractor.extract(paddedFloat)

            val encInputName = enc.inputNames.firstOrNull() ?: "mel"
            val generatedTokens = mutableListOf<Int>()

            OnnxTensor.createTensor(
                ortEnv,
                FloatBuffer.wrap(melFeatures),
                longArrayOf(1L, N_MELS.toLong(), MEL_FRAMES.toLong())
            ).use { melTensor ->
                enc.run(mapOf(encInputName to melTensor)).use { encResult ->
                    val encOutputTensor = encResult.get(0) as? OnnxTensor
                    if (encOutputTensor != null) {
                        runGreedyDecode(dec, encOutputTensor, generatedTokens)
                    }
                }
            }

            val decodedText = decodeTokensToText(generatedTokens).ifBlank {
                if (isFinalTrigger) "[靜音或無可辨識語音]" else "..."
            }

            val inferMs = SystemClock.elapsedRealtime() - inferStart
            val rtf = if (audioDurationMs > 0L) inferMs.toFloat() / audioDurationMs.toFloat() else 0f
            Log.d(
                TAG_PERF,
                "Backend=${activeBackend.label} seg=$segmentId final=$isFinalTrigger " +
                    "audioMs=$audioDurationMs inferMs=$inferMs rtf=${"%.3f".format(rtf)}"
            )

            SubtitleSegment(
                id = segmentId,
                text = decodedText,
                isFinal = isFinalTrigger,
                startTimeMs = startTimeMs,
                endTimeMs = endTimeMs,
                backendTag = activeBackend,
                latencyMs = inferMs
            )
        }
    }

    override fun release() {
        releaseInternal()
        Log.i(TAG_STATE, "LocalNpuAsrEngine unloaded & native memory released")
    }

    private fun releaseInternal() {
        isLoaded = false
        runCatching { encoderSession?.close() }
        runCatching { decoderSession?.close() }
        encoderSession = null
        decoderSession = null
    }

    private fun resolveFileDirectory(path: String): File {
        val trimmed = path.trim()
        return if (trimmed.startsWith("/")) {
            File(trimmed)
        } else {
            val externalRoot = context.getExternalFilesDir(null) ?: context.filesDir
            File(externalRoot, trimmed)
        }
    }

    private fun scanSafTree(treeUri: Uri): SafScanResult {
        return runCatching {
            val treeDocId = DocumentsContract.getTreeDocumentId(treeUri)
            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, treeDocId)
            val projection = arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_SIZE,
                DocumentsContract.Document.COLUMN_MIME_TYPE
            )
            var totalBytes = 0L
            var encId: String? = null
            var decId: String? = null
            var qnnEncId: String? = null
            var qnnDecId: String? = null
            var vocabId: String? = null

            context.contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                val nameCol = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                val sizeCol = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_SIZE)
                val mimeCol = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)

                while (cursor.moveToNext()) {
                    val docId = cursor.getString(idCol)
                    val name = cursor.getString(nameCol) ?: continue
                    val size = if (!cursor.isNull(sizeCol)) cursor.getLong(sizeCol) else 0L
                    val mime = cursor.getString(mimeCol) ?: ""
                    if (mime != DocumentsContract.Document.MIME_TYPE_DIR) {
                        totalBytes += size
                    }
                    when (name.lowercase(Locale.US)) {
                        "encoder.onnx" -> encId = docId
                        "decoder.onnx" -> decId = docId
                        "encoder_qnn_ctx.onnx" -> qnnEncId = docId
                        "decoder_qnn_ctx.onnx" -> qnnDecId = docId
                        "vocab.json" -> vocabId = docId
                    }
                }
            }
            SafScanResult(
                exists = true,
                totalBytes = totalBytes,
                encoderDocId = encId,
                decoderDocId = decId,
                qnnEncoderDocId = qnnEncId,
                qnnDecoderDocId = qnnDecId,
                vocabDocId = vocabId
            )
        }.getOrElse {
            SafScanResult(false, 0L, null, null, null, null, null)
        }
    }

    private fun prepareSafModelsIntoCache(treeUri: Uri): Result<File> = runCatching {
        val scan = scanSafTree(treeUri)
        if (!scan.exists || (scan.encoderDocId == null && scan.qnnEncoderDocId == null)) {
            throw FileNotFoundException("找不到 encoder.onnx")
        }

        val cacheDir = File(context.cacheDir, "saf_model_cache").apply {
            if (!exists()) mkdirs()
        }

        fun copyDocIfPresent(docId: String?, targetName: String) {
            if (docId == null) return
            val docUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)
            val targetFile = File(cacheDir, targetName)
            context.contentResolver.openInputStream(docUri)?.use { input ->
                targetFile.outputStream().use { output ->
                    input.copyTo(output, bufferSize = 64 * 1024)
                }
            } ?: throw FileNotFoundException("無法讀取 SAF 檔案: $targetName")
        }

        copyDocIfPresent(scan.encoderDocId, "encoder.onnx")
        copyDocIfPresent(scan.decoderDocId, "decoder.onnx")
        copyDocIfPresent(scan.qnnEncoderDocId, "encoder_qnn_ctx.onnx")
        copyDocIfPresent(scan.qnnDecoderDocId, "decoder_qnn_ctx.onnx")
        copyDocIfPresent(scan.vocabDocId, "vocab.json")
        cacheDir
    }

    private fun runGreedyDecode(
        dec: OrtSession,
        encHiddenTensor: OnnxTensor,
        outTokens: MutableList<Int>
    ) {
        val inputNames = dec.inputNames
        val tokenInputName = inputNames.firstOrNull { it.contains("input_ids") || it.contains("tokens") }
            ?: inputNames.first()
        val encStateInputName = inputNames.firstOrNull { it.contains("encoder") || it.contains("hidden") }

        val sequence = mutableListOf(
            DEFAULT_SOT.toLong(),
            DEFAULT_LANG_ZH.toLong(),
            DEFAULT_TASK_TRANSCRIBE.toLong(),
            DEFAULT_NO_TIMESTAMPS.toLong()
        )

        for (step in 0 until MAX_DECODE_TOKENS) {
            val idsArr = sequence.toLongArray()
            val idsTensor = OnnxTensor.createTensor(
                ortEnv,
                LongBuffer.wrap(idsArr),
                longArrayOf(1L, idsArr.size.toLong())
            )
            val inputs = HashMap<String, OnnxTensor>(2)
            inputs[tokenInputName] = idsTensor
            if (encStateInputName != null) {
                inputs[encStateInputName] = encHiddenTensor
            }

            val nextToken: Int = try {
                dec.run(inputs).use { decOut ->
                    extractLastStepArgmax(decOut.get(0).value)
                }
            } catch (e: OrtException) {
                Log.w(TAG_PERF, "Decoder step=$step stopped: ${e.message}")
                DEFAULT_EOT
            } finally {
                idsTensor.close()
            }

            if (nextToken == eotTokenId || nextToken == DEFAULT_EOT) break
            outTokens.add(nextToken)
            sequence.add(nextToken.toLong())
        }
    }

    private fun extractLastStepArgmax(rawValue: Any?): Int {
        val lastStepLogits: FloatArray = when (rawValue) {
            is Array<*> -> {
                val first = rawValue.firstOrNull()
                when (first) {
                    is Array<*> -> (first.lastOrNull() as? FloatArray) ?: return DEFAULT_EOT
                    is FloatArray -> first
                    else -> return DEFAULT_EOT
                }
            }
            else -> return DEFAULT_EOT
        }

        var bestIdx = DEFAULT_EOT
        var bestVal = Float.NEGATIVE_INFINITY
        for (i in lastStepLogits.indices) {
            if (lastStepLogits[i] > bestVal) {
                bestVal = lastStepLogits[i]
                bestIdx = i
            }
        }
        return bestIdx
    }

    private fun createSessionOptions(useQnnNpu: Boolean, numThreads: Int): OrtSession.SessionOptions {
        return OrtSession.SessionOptions().apply {
            setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
            setIntraOpNumThreads(numThreads)
            setInterOpNumThreads(1)
            addConfigEntry("session.intra_op.allow_spinning", "1")

            if (useQnnNpu) {
                val qnnMap = mapOf(
                    "backend_path" to "libQnnHtp.so",
                    "htp_performance_mode" to "burst",
                    "htp_graph_finalization_optimization_mode" to "3",
                    "enable_htp_fp16_precision" to "1"
                )
                val addQnnMethod = OrtSession.SessionOptions::class.java
                    .getMethod("addQnn", Map::class.java)
                addQnnMethod.invoke(this, qnnMap)
            } else {
                runCatching {
                    addXnnpack(mapOf("intra_op_num_threads" to numThreads.toString()))
                }
            }
        }
    }

    private fun isQnnHtpSupported(): Boolean {
        val isQualcomm = Build.HARDWARE.contains("qcom", ignoreCase = true) ||
            Build.SOC_MANUFACTURER.contains("Qualcomm", ignoreCase = true)
        if (!isQualcomm) return false

        val nativeLibPath = context.applicationInfo.nativeLibraryDir
        val hasLocalQnn = File(nativeLibPath, "libQnnHtp.so").exists()
        val hasSystemQnn = File("/vendor/lib64/libQnnHtp.so").exists() ||
            File("/system/vendor/lib64/libQnnHtp.so").exists()
        return hasLocalQnn || hasSystemQnn
    }

    private fun loadTokenizerIfPresent(modelDir: File) {
        val vocabFile = File(modelDir, "vocab.json")
        if (!vocabFile.exists()) {
            idToToken = emptyMap()
            return
        }
        runCatching {
            val json = JSONObject(vocabFile.readText())
            val map = HashMap<Int, String>(json.length())
            val keys = json.keys()
            while (keys.hasNext()) {
                val token = keys.next()
                val id = json.getInt(token)
                map[id] = token
                if (token == "<|endoftext|>") eotTokenId = id
            }
            idToToken = map
        }.onFailure {
            Log.w(TAG_STATE, "vocab.json 解析失敗: ${it.message}")
        }
    }

    private fun decodeTokensToText(tokens: List<Int>): String {
        if (tokens.isEmpty()) return ""
        if (idToToken.isEmpty()) {
            return tokens.joinToString(" ") { "#$it" }
        }
        val byteStream = ByteArrayOutputStream()
        for (id in tokens) {
            val tok = idToToken[id] ?: continue
            if (tok.startsWith("<|") && tok.endsWith("|>")) continue
            for (ch in tok) {
                val b = unicodeToByte[ch]
                if (b != null) {
                    byteStream.write(b.toInt() and 0xFF)
                } else {
                    val utf8 = ch.toString().toByteArray(Charsets.UTF_8)
                    byteStream.write(utf8, 0, utf8.size)
                }
            }
        }
        return byteStream.toByteArray().toString(Charsets.UTF_8).trim()
    }

    private fun buildWhisperUnicodeToByteMap(): Map<Char, Byte> {
        val bs = mutableListOf<Int>()
        for (b in 33..126) bs.add(b)
        for (b in 161..172) bs.add(b)
        for (b in 174..255) bs.add(b)

        val cs = bs.toMutableList()
        var n = 0
        for (b in 0..255) {
            if (b !in bs) {
                bs.add(b)
                cs.add(256 + n)
                n++
            }
        }
        val map = HashMap<Char, Byte>(bs.size)
        for (i in bs.indices) {
            map[cs[i].toChar()] = bs[i].toByte()
        }
        return map
    }

    private class WhisperLogMelExtractor {
        private val fftSize = 512
        private val winSize = 400
        private val hopSize = 160
        private val nBins = fftSize / 2 + 1

        private val hannWindow = FloatArray(winSize) { i ->
            (0.5 * (1.0 - cos(2.0 * PI * i / winSize))).toFloat()
        }
        private val melFilterBank: Array<FloatArray> = buildMelFilterBank()

        fun extract(padded30sPcm: FloatArray): FloatArray {
            val melOut = FloatArray(N_MELS * MEL_FRAMES)
            val real = FloatArray(fftSize)
            val imag = FloatArray(fftSize)
            val powerSpec = FloatArray(nBins)
            var maxLogMel = -10.0f

            for (frame in 0 until MEL_FRAMES) {
                val startSample = frame * hopSize
                real.fill(0f)
                imag.fill(0f)

                for (i in 0 until winSize) {
                    val idx = startSample + i
                    if (idx < padded30sPcm.size) {
                        real[i] = padded30sPcm[idx] * hannWindow[i]
                    }
                }

                fftRadix2(real, imag)

                for (k in 0 until nBins) {
                    powerSpec[k] = real[k] * real[k] + imag[k] * imag[k]
                }

                for (m in 0 until N_MELS) {
                    val weights = melFilterBank[m]
                    var energy = 0f
                    for (k in 0 until nBins) {
                        energy += weights[k] * powerSpec[k]
                    }
                    val logVal = log10(max(energy, 1e-10f))
                    melOut[m * MEL_FRAMES + frame] = logVal
                    if (logVal > maxLogMel) maxLogMel = logVal
                }
            }

            val minClamp = maxLogMel - 8.0f
            for (i in melOut.indices) {
                val clamped = max(melOut[i], minClamp)
                melOut[i] = (clamped + 4.0f) / 4.0f
            }
            return melOut
        }

        private fun fftRadix2(real: FloatArray, imag: FloatArray) {
            val n = real.size
            var j = 0
            for (i in 1 until n) {
                var bit = n shr 1
                while (j and bit != 0) {
                    j = j xor bit
                    bit = bit shr 1
                }
                j = j xor bit
                if (i < j) {
                    val tr = real[i]; real[i] = real[j]; real[j] = tr
                    val ti = imag[i]; imag[i] = imag[j]; imag[j] = ti
                }
            }

            var len = 2
            while (len <= n) {
                val ang = -2.0 * PI / len
                val wLenReal = cos(ang).toFloat()
                val wLenImag = sin(ang).toFloat()
                var i = 0
                while (i < n) {
                    var wReal = 1f
                    var wImag = 0f
                    for (k in 0 until len / 2) {
                        val uReal = real[i + k]
                        val uImag = imag[i + k]
                        val vReal = real[i + k + len / 2] * wReal - imag[i + k + len / 2] * wImag
                        val vImag = real[i + k + len / 2] * wImag + imag[i + k + len / 2] * wReal
                        real[i + k] = uReal + vReal
                        imag[i + k] = uImag + vImag
                        real[i + k + len / 2] = uReal - vReal
                        imag[i + k + len / 2] = uImag - vImag
                        val nextWReal = wReal * wLenReal - wImag * wLenImag
                        wImag = wReal * wLenImag + wImag * wLenReal
                        wReal = nextWReal
                    }
                    i += len
                }
                len = len shl 1
            }
        }

        private fun buildMelFilterBank(): Array<FloatArray> {
            fun hzToMel(hz: Double): Double = 2595.0 * log10(1.0 + hz / 700.0)
            fun melToHz(mel: Double): Double = 700.0 * (10.0.pow(mel / 2595.0) - 1.0)

            val melMin = hzToMel(0.0)
            val melMax = hzToMel(SAMPLE_RATE / 2.0)
            val melPoints = DoubleArray(N_MELS + 2) { idx ->
                melMin + (melMax - melMin) * idx / (N_MELS + 1)
            }
            val fftFreqs = DoubleArray(nBins) { k ->
                (SAMPLE_RATE / 2.0) * k / (nBins - 1)
            }
            val hzPoints = DoubleArray(N_MELS + 2) { melToHz(melPoints[it]) }

            return Array(N_MELS) { m ->
                val fLeft = hzPoints[m]
                val fCenter = hzPoints[m + 1]
                val fRight = hzPoints[m + 2]
                val enorm = 2.0 / (fRight - fLeft)
                FloatArray(nBins) { k ->
                    val f = fftFreqs[k]
                    val weight = when {
                        f in fLeft..fCenter && fCenter > fLeft -> (f - fLeft) / (fCenter - fLeft)
                        f in fCenter..fRight && fRight > fCenter -> (fRight - f) / (fRight - fCenter)
                        else -> 0.0
                    }
                    (weight * enorm).toFloat()
                }
            }
        }
    }
}
