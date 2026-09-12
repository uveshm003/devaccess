package com.devaccess.app.monitor

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Choreographer
import android.view.Gravity
import android.view.WindowManager
import android.widget.TextView
import com.devaccess.app.R

/**
 * FR-MON-6 — opt-in on-screen FPS / frame-time overlay.
 *
 * Frame timing comes from [Choreographer]: each vsync callback timestamp is recorded and a
 * one-second rolling window yields FPS plus the 1 % worst frame time. This measures the
 * cadence the compositor delivers to DevAccess, which is the number a developer wants when
 * eyeballing jank on the device itself.
 */
class OverlayService : Service() {

    companion object {
        const val ACTION_START = "com.devaccess.app.overlay.START"
        const val ACTION_STOP = "com.devaccess.app.overlay.STOP"
        private const val CHANNEL_ID = "devaccess.overlay"
        private const val NOTIFICATION_ID = 4202

        @Volatile var running: Boolean = false
            private set

        fun hasPermission(context: Context): Boolean = Settings.canDrawOverlays(context)

        fun start(context: Context) {
            val i = Intent(context, OverlayService::class.java).setAction(ACTION_START)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(i)
            } else {
                context.startService(i)
            }
        }

        fun stop(context: Context) {
            context.startService(Intent(context, OverlayService::class.java).setAction(ACTION_STOP))
        }
    }

    private var view: TextView? = null
    private var wm: WindowManager? = null
    private val frameTimes = ArrayDeque<Long>()
    private var lastFrameNs = 0L
    private var worstMs = 0.0
    private var lastRender = 0L

    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            if (!running) return
            if (lastFrameNs != 0L) {
                val deltaMs = (frameTimeNanos - lastFrameNs) / 1_000_000.0
                if (deltaMs > worstMs) worstMs = deltaMs
            }
            lastFrameNs = frameTimeNanos
            frameTimes.addLast(frameTimeNanos)
            val cutoff = frameTimeNanos - 1_000_000_000L
            while (frameTimes.isNotEmpty() && frameTimes.first() < cutoff) frameTimes.removeFirst()

            val nowMs = frameTimeNanos / 1_000_000
            if (nowMs - lastRender >= 250) {
                lastRender = nowMs
                render()
            }
            Choreographer.getInstance().postFrameCallback(this)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            teardown()
            return START_NOT_STICKY
        }
        if (!hasPermission(this)) {
            // SYSTEM_ALERT_WINDOW revoked while running — fail closed (NFR-RELIABILITY-1).
            teardown()
            return START_NOT_STICKY
        }
        createChannel()
        startForegroundCompat()
        if (view == null) attachOverlay()
        running = true
        Choreographer.getInstance().postFrameCallback(frameCallback)
        return START_STICKY
    }

    private fun attachOverlay() {
        val tv = TextView(this).apply {
            setBackgroundColor(Color.argb(190, 0, 0, 0))
            setTextColor(Color.WHITE)
            textSize = 11f
            setPadding(16, 10, 16, 10)
            text = "…"
        }
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 24
            y = 120
        }
        wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        try {
            wm?.addView(tv, params)
            view = tv
        } catch (t: Throwable) {
            teardown()
        }
    }

    private fun render() {
        val fps = frameTimes.size
        val avgMs = if (fps > 1) {
            (frameTimes.last() - frameTimes.first()) / 1_000_000.0 / (fps - 1)
        } else {
            0.0
        }
        val text = "FPS %d · avg %.1f ms · worst %.1f ms".format(fps, avgMs, worstMs)
        worstMs = 0.0
        view?.post { view?.text = text }
    }

    private fun startForegroundCompat() {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val n = builder
            .setContentTitle(getString(R.string.overlay_title))
            .setContentText(getString(R.string.overlay_text))
            .setSmallIcon(R.drawable.ic_tile_dash)
            .setOngoing(true)
            .build()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIFICATION_ID, n)
            }
        } catch (_: Throwable) {
            // A blocked notification must not stop the overlay itself.
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) == null) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID, getString(R.string.overlay_title), NotificationManager.IMPORTANCE_MIN,
                ),
            )
        }
    }

    private fun teardown() {
        running = false
        try { Choreographer.getInstance().removeFrameCallback(frameCallback) } catch (_: Throwable) {}
        view?.let { v -> try { wm?.removeView(v) } catch (_: Throwable) {} }
        view = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        teardown()
        super.onDestroy()
    }
}
