package com.devaccess.app.monitor

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import com.devaccess.app.MainActivity
import com.devaccess.app.R
import com.devaccess.app.info.MemoryStorageInfo
import com.devaccess.app.surface.StatsWidgetProvider

/**
 * FR-MON-7 — live monitors run in a foreground service *only while active*, and stop
 * cleanly when dismissed. The notification carries a Stop action so the user can always
 * end it without returning to the app.
 *
 * NFR-PERF-2 — sampling is paused while the screen is off.
 */
class MonitorService : Service() {

    companion object {
        const val ACTION_START = "com.devaccess.app.monitor.START"
        const val ACTION_STOP = "com.devaccess.app.monitor.STOP"
        const val EXTRA_INTERVAL = "intervalMs"
        private const val CHANNEL_ID = "devaccess.monitor"
        private const val NOTIFICATION_ID = 4201

        @Volatile var running: Boolean = false
            private set

        fun start(context: Context, intervalMs: Long) {
            val i = Intent(context, MonitorService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_INTERVAL, intervalMs)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(i)
            } else {
                context.startService(i)
            }
        }

        fun stop(context: Context) {
            context.startService(
                Intent(context, MonitorService::class.java).setAction(ACTION_STOP),
            )
        }
    }

    private val listener = MonitorEngine.Listener { sample -> onSample(sample) }
    private var lastNotificationUpdate = 0L

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> MonitorEngine.setPaused(true)
                Intent.ACTION_SCREEN_ON -> MonitorEngine.setPaused(false)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(screenReceiver, filter)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelfCleanly()
            return START_NOT_STICKY
        }
        val interval = intent?.getLongExtra(EXTRA_INTERVAL, MonitorEngine.DEFAULT_INTERVAL_MS)
            ?: MonitorEngine.DEFAULT_INTERVAL_MS

        startForegroundCompat(buildNotification("Starting…"))
        running = true
        MonitorEngine.addListener(this, listener, interval)
        return START_STICKY
    }

    private fun startForegroundCompat(n: Notification) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIFICATION_ID, n)
            }
        } catch (t: Throwable) {
            // POST_NOTIFICATIONS denied on 13+ leaves a silent service; sampling still works.
            stopSelfCleanly()
        }
    }

    private fun onSample(sample: Map<String, Any?>) {
        val now = System.currentTimeMillis()
        // The notification is text only — refresh it at most once a second regardless of the
        // sampling rate, and let the widget follow the same cadence.
        if (now - lastNotificationUpdate < 1000) return
        lastNotificationUpdate = now

        @Suppress("UNCHECKED_CAST")
        val cpu = sample["cpu"] as? Map<String, Any?>
        @Suppress("UNCHECKED_CAST")
        val mem = sample["memory"] as? Map<String, Any?>
        @Suppress("UNCHECKED_CAST")
        val batt = sample["battery"] as? Map<String, Any?>

        val text = buildString {
            (cpu?.get("totalLoad") as? Double)?.let { append("CPU %.0f%%  ".format(it)) }
            (mem?.get("used") as? Long)?.let { used ->
                append("RAM ").append(MemoryStorageInfo.human(used)).append("  ")
            }
            (batt?.get("level") as? Int)?.let { append(it).append("%") }
            (batt?.get("temperature") as? Double)?.let { append(" %.1f°C".format(it)) }
        }.ifBlank { getString(R.string.monitor_text) }

        try {
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .notify(NOTIFICATION_ID, buildNotification(text))
        } catch (_: Throwable) {
            // Notifications may be blocked; the service keeps sampling regardless.
        }
        StatsWidgetProvider.pushSample(this, sample)
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                getString(R.string.monitor_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = getString(R.string.monitor_channel_desc)
                setShowBadge(false)
            },
        )
    }

    private fun buildNotification(text: String): Notification {
        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                .putExtra(MainActivity.EXTRA_ROUTE, "monitor"),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stop = PendingIntent.getService(
            this, 1,
            Intent(this, MonitorService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle(getString(R.string.monitor_title))
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_tile_dash)
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(
                Notification.Action.Builder(null, getString(R.string.monitor_stop), stop).build(),
            )
            .build()
    }

    private fun stopSelfCleanly() {
        running = false
        MonitorEngine.removeListener(listener)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        running = false
        MonitorEngine.removeListener(listener)
        try { unregisterReceiver(screenReceiver) } catch (_: Throwable) {}
        MonitorEngine.setPaused(false)
        super.onDestroy()
    }
}
