package com.example.offlinesubtitle.service

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Binder
import android.os.Debug
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.lifecycle.LifecycleService
import androidx.lifecycle.lifecycleScope
import com.example.offlinesubtitle.MainActivity
import com.example.offlinesubtitle.asr.LocalNpuAsrEngine
import com.example.offlinesubtitle.asr.MockNpuAsrEngine
import com.example.offlinesubtitle.audio.AudioCaptureManager
import com.example.offlinesubtitle.audio.AudioInputSource
import com.example.offlinesubtitle.subtitle.SubtitleStateManager
import com.example.offlinesubtitle.ui.FloatingSubtitleOverlay
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

object SubtitleRuntimeCoordinator {
    @Volatile
    private var stateManager: SubtitleStateManager? = null
    @Volatile
    private var mockEngine: MockNpuAsrEngine? = null
    @Volatile
    private var localEngine: LocalNpuAsrEngine? = null

    fun getOrCreateStateManager(appContext: Context): SubtitleStateManager {
        return stateManager ?: synchronized(this) {
            stateManager ?: run {
                val ctx = appContext.applicationContext
                val mock = MockNpuAsrEngine().also { mockEngine = it }
                val local = LocalNpuAsrEngine(ctx).also { localEngine = it }
                SubtitleStateManager(
                    audioCaptureManager = AudioCaptureManager(),
                    initialEngine = mock,
                    localNpuAsrEngine = local
                ).also { stateManager = it }
            }
        }
    }

    fun getMockEngine(): MockNpuAsrEngine = mockEngine ?: MockNpuAsrEngine().also { mockEngine = it }

    fun getLocalEngine(appContext: Context): LocalNpuAsrEngine =
        localEngine ?: LocalNpuAsrEngine(appContext.applicationContext).also { localEngine = it }
}

class SubtitleForegroundService : LifecycleService() {

    companion object {
        private const val TAG_SERVICE = "[ASR_SERVICE]"
        private const val CHANNEL_ID = "offline_subtitle_channel"
        private const val NOTIFICATION_ID = 1001
        private const val HEARTBEAT_INTERVAL_MS = 15_000L

        const val ACTION_START_MIC = "com.example.offlinesubtitle.action.START_MIC"
        const val ACTION_START_SIMULATED = "com.example.offlinesubtitle.action.START_SIMULATED"
        const val ACTION_START_SYSTEM_AUDIO = "com.example.offlinesubtitle.action.START_SYSTEM_AUDIO"
        const val ACTION_STOP = "com.example.offlinesubtitle.action.STOP"
        const val ACTION_SHOW_OVERLAY = "com.example.offlinesubtitle.action.SHOW_OVERLAY"
        const val ACTION_HIDE_OVERLAY = "com.example.offlinesubtitle.action.HIDE_OVERLAY"

        const val EXTRA_RESULT_CODE = "extra_result_code"
        const val EXTRA_RESULT_DATA = "extra_result_data"
    }

    inner class LocalBinder : Binder() {
        fun getService(): SubtitleForegroundService = this@SubtitleForegroundService
    }

    private val binder = LocalBinder()
    private lateinit var stateManager: SubtitleStateManager
    private lateinit var floatingOverlay: FloatingSubtitleOverlay

    private var wakeLock: PowerManager.WakeLock? = null
    private var mediaProjection: MediaProjection? = null
    private var heartbeatJob: Job? = null
    private var serviceStartElapsedMs: Long = 0L

    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            Log.w(TAG_SERVICE, "MediaProjection stopped by system")
            stopPipelineAndService()
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        stateManager = SubtitleRuntimeCoordinator.getOrCreateStateManager(applicationContext)
        floatingOverlay = FloatingSubtitleOverlay(
            context = applicationContext,
            stateManager = stateManager,
            onSwitchSourceRequest = { nextSource ->
                handleOverlaySourceSwitch(nextSource)
            },
            onCloseOverlay = {
                hideOverlay()
            }
        )
        Log.i(TAG_SERVICE, "SubtitleForegroundService created")
    }

    override fun onBind(intent: Intent): IBinder {
        super.onBind(intent)
        return binder
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        when (intent?.action) {
            ACTION_START_MIC -> startMicOrSimMode(AudioInputSource.MICROPHONE)
            ACTION_START_SIMULATED -> startMicOrSimMode(AudioInputSource.SIMULATED_PCM)
            ACTION_START_SYSTEM_AUDIO -> {
                val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
                @Suppress("DEPRECATION")
                val resultData = intent.getParcelableExtra<Intent>(EXTRA_RESULT_DATA)
                if (resultCode == Activity.RESULT_OK && resultData != null) {
                    startSystemAudioMode(resultCode, resultData)
                } else {
                    Log.e(TAG_SERVICE, "MediaProjection intent invalid, stopping service")
                    stopSelf()
                }
            }
            ACTION_SHOW_OVERLAY -> {
                ensureForegroundForOverlayIfIdle()
                showOverlay()
            }
            ACTION_HIDE_OVERLAY -> hideOverlay()
            ACTION_STOP -> stopPipelineAndService()
        }
        return START_NOT_STICKY
    }

    private fun startMicOrSimMode(source: AudioInputSource) {
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            buildNotification("即時字幕運作中（${source.label}）"),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        )
        acquireWakeLock()
        startHeartbeat()
        stateManager.setInputSource(source)
        stateManager.start()
        Log.i(TAG_SERVICE, "ForegroundService started with MICROPHONE type, source=${source.name}")
    }

    private fun startSystemAudioMode(resultCode: Int, resultData: Intent) {
        val fgsType = ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION or
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            buildNotification("系統音訊字幕擷取中 (MediaProjection)"),
            fgsType
        )

        val projectionManager = getSystemService(MediaProjectionManager::class.java)
        mediaProjection?.unregisterCallback(projectionCallback)
        mediaProjection?.stop()

        val projection = projectionManager.getMediaProjection(resultCode, resultData)
        projection.registerCallback(projectionCallback, null)
        mediaProjection = projection

        acquireWakeLock()
        startHeartbeat()
        stateManager.setInputSource(AudioInputSource.SYSTEM_AUDIO)
        stateManager.start(mediaProjection = projection)
        Log.i(TAG_SERVICE, "ForegroundService started with MEDIA_PROJECTION type")
    }

    private fun ensureForegroundForOverlayIfIdle() {
        if (stateManager.uiState.value.isRunning) return
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            buildNotification("懸浮字幕視窗待命中"),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        )
        acquireWakeLock()
        startHeartbeat()
    }

    private fun handleOverlaySourceSwitch(nextSource: AudioInputSource) {
        if (nextSource == AudioInputSource.SYSTEM_AUDIO && mediaProjection == null) {
            Log.w(TAG_SERVICE, "Cannot switch to SYSTEM_AUDIO from overlay without MediaProjection consent")
            return
        }
        stateManager.stop()
        stateManager.setInputSource(nextSource)
        if (nextSource == AudioInputSource.SYSTEM_AUDIO) {
            stateManager.start(mediaProjection = mediaProjection)
        } else {
            stateManager.start()
        }
    }

    fun showOverlay() {
        floatingOverlay.show()
        stateManager.setOverlayActive(true)
        Log.i(TAG_SERVICE, "FloatingSubtitleOverlay shown")
    }

    fun hideOverlay() {
        floatingOverlay.hide()
        stateManager.setOverlayActive(false)
        Log.i(TAG_SERVICE, "FloatingSubtitleOverlay hidden")
    }

    private fun stopPipelineAndService() {
        stateManager.stop()
        hideOverlay()
        releaseProjection()
        releaseWakeLock()
        heartbeatJob?.cancel()
        heartbeatJob = null
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
        Log.i(TAG_SERVICE, "SubtitleForegroundService stopped cleanly")
    }

    private fun startHeartbeat() {
        if (heartbeatJob?.isActive == true) return
        serviceStartElapsedMs = SystemClock.elapsedRealtime()
        heartbeatJob = lifecycleScope.launch {
            while (isActive) {
                val uptimeSec = (SystemClock.elapsedRealtime() - serviceStartElapsedMs) / 1000L
                val pssMb = Debug.getPss() / 1024f
                stateManager.updateServiceHeartbeatMetrics(pssMemoryMb = pssMb)
                val ui = stateManager.uiState.value
                Log.i(
                    TAG_SERVICE,
                    "HEARTBEAT uptime=${uptimeSec}s running=${ui.isRunning} " +
                        "source=${ui.inputSource.name} Backend=${ui.backendTag.label} " +
                        "drift=${ui.timelineDriftMs}ms pss=${"%.1f".format(pssMb)}MB"
                )
                delay(HEARTBEAT_INTERVAL_MS)
            }
        }
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(PowerManager::class.java)
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "OfflineSubtitle:AsrWakeLock").apply {
            setReferenceCounted(false)
            acquire(2 * 60 * 60 * 1000L)
        }
        Log.d(TAG_SERVICE, "PARTIAL_WAKE_LOCK acquired")
    }

    private fun releaseWakeLock() {
        runCatching {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        }
        wakeLock = null
    }

    private fun releaseProjection() {
        runCatching {
            mediaProjection?.unregisterCallback(projectionCallback)
            mediaProjection?.stop()
        }
        mediaProjection = null
    }

    private fun createNotificationChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "離線即時字幕服務",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "維持背景與鎖屏期間離線字幕推論不斷線"
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(contentText: String): Notification {
        val openAppIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val stopIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, SubtitleForegroundService::class.java).apply { action = ACTION_STOP },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("OfflineSubtitle 離線字幕")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(openAppIntent)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_media_pause, "停止", stopIntent)
            .build()
    }

    override fun onDestroy() {
        super.onDestroy()
        floatingOverlay.hide()
        releaseProjection()
        releaseWakeLock()
        heartbeatJob?.cancel()
        Log.i(TAG_SERVICE, "SubtitleForegroundService destroyed")
    }
}
