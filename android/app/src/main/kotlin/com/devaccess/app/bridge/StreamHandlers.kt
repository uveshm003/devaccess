package com.devaccess.app.bridge

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import com.devaccess.app.monitor.MonitorEngine
import com.devaccess.app.net.NetTools
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * FR-MON-* — streams a telemetry sample per interval to whichever Dart view is listening.
 * The sampling loop itself is shared with the foreground service, so nothing is sampled twice.
 */
class MonitorStreamHandler(private val context: Context) : EventChannel.StreamHandler {

    private val main = Handler(Looper.getMainLooper())
    private var listener: MonitorEngine.Listener? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        if (events == null) return
        @Suppress("UNCHECKED_CAST")
        val args = arguments as? Map<String, Any?>
        val interval = (args?.get("intervalMs") as? Number)?.toLong()

        val l = MonitorEngine.Listener { sample -> main.post { events.success(sample) } }
        listener = l
        MonitorEngine.addListener(context, l, interval)
    }

    override fun onCancel(arguments: Any?) {
        listener?.let { MonitorEngine.removeListener(it) }
        listener = null
    }
}

/**
 * FR-SEN-2 — live sensor values. One subscription per sensor type; the delay is chosen by
 * Dart so a rolling graph can trade smoothness against battery (NFR-PERF-2).
 */
class SensorStreamHandler(private val context: Context) : EventChannel.StreamHandler {

    private val main = Handler(Looper.getMainLooper())
    private var sm: SensorManager? = null
    private var listener: SensorEventListener? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        if (events == null) return
        @Suppress("UNCHECKED_CAST")
        val args = arguments as? Map<String, Any?>
        val type = (args?.get("type") as? Number)?.toInt()
        if (type == null) {
            events.error("bad_args", "A sensor 'type' is required", null)
            return
        }
        val delayUs = (args["delayUs"] as? Number)?.toInt() ?: SensorManager.SENSOR_DELAY_UI

        val manager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        if (manager == null) {
            events.error("unavailable", "No SensorManager on this device", null)
            return
        }
        val sensor: Sensor? = manager.getDefaultSensor(type)
        if (sensor == null) {
            events.error("unavailable", "This device has no sensor of type $type", null)
            return
        }
        sm = manager
        val l = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                val payload = mapOf(
                    "type" to event.sensor.type,
                    "values" to event.values.map { it.toDouble() },
                    "accuracy" to event.accuracy,
                    "timestamp" to event.timestamp,
                )
                main.post { events.success(payload) }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
                main.post { events.success(mapOf("type" to (sensor?.type ?: -1), "accuracy" to accuracy)) }
            }
        }
        listener = l
        manager.registerListener(l, sensor, delayUs)
    }

    override fun onCancel(arguments: Any?) {
        listener?.let { sm?.unregisterListener(it) }
        listener = null
        sm = null
    }
}

/**
 * FR-NET-4 — ping and traceroute stream their output line by line so the UI fills in as the
 * probes come back. Cancelling the Dart subscription kills the child process.
 */
class NetToolStreamHandler : EventChannel.StreamHandler {

    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private val cancelled = AtomicBoolean(false)

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        if (events == null) return
        @Suppress("UNCHECKED_CAST")
        val args = arguments as? Map<String, Any?> ?: run {
            events.error("bad_args", "Arguments are required", null)
            return
        }
        cancelled.set(false)
        val tool = args["tool"] as? String ?: "ping"
        val host = (args["host"] as? String)?.trim().orEmpty()
        if (host.isEmpty()) {
            events.error("bad_args", "A host is required", null)
            return
        }
        val sink = NetTools.Sink { event -> main.post { if (!cancelled.get()) events.success(event) } }

        io.execute {
            try {
                when (tool) {
                    "ping" -> NetTools.ping(host, (args["count"] as? Number)?.toInt() ?: 4, sink) { cancelled.get() }
                    "traceroute" -> NetTools.traceroute(host, (args["maxHops"] as? Number)?.toInt() ?: 20, sink) { cancelled.get() }
                    else -> sink.emit(mapOf("type" to "error", "text" to "Unknown tool '$tool'"))
                }
            } catch (t: Throwable) {
                sink.emit(mapOf("type" to "error", "text" to "${t.javaClass.simpleName}: ${t.message}"))
            } finally {
                main.post { if (!cancelled.get()) events.endOfStream() }
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        cancelled.set(true)
    }

    fun dispose() {
        cancelled.set(true)
        io.shutdownNow()
    }
}
