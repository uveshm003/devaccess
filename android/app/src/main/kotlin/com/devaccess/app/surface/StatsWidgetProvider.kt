package com.devaccess.app.surface

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.devaccess.app.MainActivity
import com.devaccess.app.R
import com.devaccess.app.info.MemoryStorageInfo
import com.devaccess.app.monitor.MonitorEngine

/**
 * FR-SURF-2 — home-screen widget with battery temperature, RAM and CPU.
 *
 * Refresh cadence: the manifest asks the platform for a 30-minute update (the floor the OS
 * honours), and while the monitor service is running each sample is pushed straight through
 * so the widget tracks live. No extra wake-ups are scheduled (NFR-PERF-2).
 */
class StatsWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_REFRESH = "com.devaccess.app.WIDGET_REFRESH"

        /** Called by MonitorService on every sample; cheap and allocation-light. */
        fun pushSample(context: Context, sample: Map<String, Any?>) {
            val mgr = AppWidgetManager.getInstance(context) ?: return
            val ids = mgr.getAppWidgetIds(ComponentName(context, StatsWidgetProvider::class.java))
            if (ids.isEmpty()) return
            val views = render(context, sample)
            mgr.updateAppWidget(ids, views)
        }

        private fun render(context: Context, sample: Map<String, Any?>?): RemoteViews {
            val v = RemoteViews(context.packageName, R.layout.widget_stats)

            @Suppress("UNCHECKED_CAST")
            val battery = sample?.get("battery") as? Map<String, Any?>
            @Suppress("UNCHECKED_CAST")
            val memory = sample?.get("memory") as? Map<String, Any?>
            @Suppress("UNCHECKED_CAST")
            val cpu = sample?.get("cpu") as? Map<String, Any?>

            val batteryText = buildString {
                append("🔋 ")
                append(battery?.get("level")?.let { "$it%" } ?: "—")
                (battery?.get("temperature") as? Double)?.let { append("\n%.1f°C".format(it)) }
            }
            val memoryText = buildString {
                append("▦ ")
                val used = memory?.get("used") as? Long
                val total = memory?.get("total") as? Long
                if (used != null && total != null && total > 0) {
                    append("${used * 100 / total}%")
                    append("\n").append(MemoryStorageInfo.human(used))
                } else {
                    append("—")
                }
            }
            val cpuText = buildString {
                append("⚙ ")
                val load = cpu?.get("totalLoad") as? Double
                append(if (load != null) "%.0f%%".format(load) else "—")
                (cpu?.get("coreCount") as? Int)?.let { append("\n$it cores") }
            }

            v.setTextViewText(R.id.widget_battery, batteryText)
            v.setTextViewText(R.id.widget_memory, memoryText)
            v.setTextViewText(R.id.widget_cpu, cpuText)

            val open = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java)
                    .putExtra(MainActivity.EXTRA_ROUTE, "monitor")
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            v.setOnClickPendingIntent(R.id.widget_root, open)
            return v
        }

        fun refreshAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context) ?: return
            val ids = mgr.getAppWidgetIds(ComponentName(context, StatsWidgetProvider::class.java))
            if (ids.isEmpty()) return
            // Prefer the running loop's latest sample; take a one-off reading otherwise.
            val sample = MonitorEngine.lastSample ?: try {
                MonitorEngine.sample(context)
            } catch (t: Throwable) {
                null
            }
            mgr.updateAppWidget(ids, render(context, sample))
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        refreshAll(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH) refreshAll(context)
    }
}
