package com.devaccess.app.monitor

import android.content.Context
import android.os.Handler
import android.os.HandlerThread
import android.os.SystemClock
import com.devaccess.app.info.CpuInfo
import com.devaccess.app.info.MemoryStorageInfo
import com.devaccess.app.info.NetInfo
import com.devaccess.app.info.PowerInfo

/**
 * FR-MON-1..5, FR-MON-7 — the single sampling loop behind the live dashboard, the
 * foreground service and the home-screen widget.
 *
 * One loop, many listeners: whether the UI, the service or the widget asks, the device is
 * only polled once per interval (NFR-PERF-2).
 */
object MonitorEngine {

    const val DEFAULT_INTERVAL_MS = 1000L
    const val MIN_INTERVAL_MS = 250L

    fun interface Listener {
        fun onSample(sample: Map<String, Any?>)
    }

    private val listeners = mutableSetOf<Listener>()
    private var thread: HandlerThread? = null
    private var handler: Handler? = null
    private var intervalMs: Long = DEFAULT_INTERVAL_MS

    @Volatile private var running = false
    @Volatile private var paused = false
    @Volatile private var appContext: Context? = null
    @Volatile var lastSample: Map<String, Any?>? = null
        private set

    private var prevTraffic: NetInfo.Traffic? = null
    private var prevTrafficAt: Long = 0
    private var prevBatteryLevel: Int? = null
    private var prevBatteryAt: Long = 0

    @Synchronized
    fun addListener(context: Context, listener: Listener, requestedIntervalMs: Long?) {
        appContext = context.applicationContext
        requestedIntervalMs?.let { intervalMs = it.coerceAtLeast(MIN_INTERVAL_MS) }
        listeners += listener
        start()
    }

    @Synchronized
    fun removeListener(listener: Listener) {
        listeners -= listener
        if (listeners.isEmpty()) stop()
    }

    @Synchronized
    fun setInterval(ms: Long) {
        intervalMs = ms.coerceAtLeast(MIN_INTERVAL_MS)
    }

    fun interval(): Long = intervalMs

    /** NFR-PERF-2 — the UI pauses sampling when its view is hidden or the screen is off. */
    fun setPaused(value: Boolean) {
        paused = value
    }

    fun isRunning(): Boolean = running

    @Synchronized
    private fun start() {
        if (running) return
        val t = HandlerThread("devaccess-monitor").also { it.start() }
        thread = t
        handler = Handler(t.looper)
        running = true
        // Prime the CPU load deltas so the first emitted sample already carries a load figure.
        CpuInfo.sampleLoad()
        handler?.post(loop)
    }

    @Synchronized
    private fun stop() {
        running = false
        handler?.removeCallbacksAndMessages(null)
        thread?.quitSafely()
        thread = null
        handler = null
        prevTraffic = null
        prevBatteryLevel = null
    }

    private val loop = object : Runnable {
        override fun run() {
            if (!running) return
            if (!paused) {
                val ctx = appContext
                if (ctx != null) {
                    val sample = try {
                        sample(ctx)
                    } catch (t: Throwable) {
                        mapOf("error" to "${t.javaClass.simpleName}: ${t.message}")
                    }
                    lastSample = sample
                    val snapshot = synchronized(this@MonitorEngine) { listeners.toList() }
                    snapshot.forEach {
                        try { it.onSample(sample) } catch (_: Throwable) { /* a bad listener must not stop sampling */ }
                    }
                }
            }
            handler?.postDelayed(this, intervalMs)
        }
    }

    /** One full pass over CPU, memory, battery, thermal and throughput. */
    fun sample(context: Context): Map<String, Any?> {
        val now = SystemClock.elapsedRealtime()

        val cores = CpuInfo.cores(withLoad = true)
        val cpu = mapOf(
            "coreCount" to CpuInfo.coreCount(),
            "totalLoad" to cores.mapNotNull { it.loadPercent }.average().takeIf { !it.isNaN() },
            "cores" to cores.map { it.toMap() },
            "clusters" to CpuInfo.clusters(cores),
            "governor" to cores.firstOrNull()?.governor,
            "loadReadable" to cores.any { it.loadPercent != null },
            "freqReadable" to cores.any { it.curKHz != null },
        )

        val mem = MemoryStorageInfo.snapshot(context).toMap()

        val batt = PowerInfo.batterySnapshot(context)
        // Estimated rate: prefer the hardware current reading, fall back to level deltas.
        val ratePerHour = estimateRate(batt.levelPercent, now)
        val battery = batt.toMap() + mapOf(
            "ratePercentPerHour" to ratePerHour,
            "estimateMinutes" to estimateMinutes(batt, ratePerHour),
        )

        val thermal = PowerInfo.thermalSnapshot(context).toMap()

        val traffic = NetInfo.traffic()
        val net = throughput(traffic, now)

        return mapOf(
            "at" to System.currentTimeMillis(),
            "uptimeMs" to now,
            "intervalMs" to intervalMs,
            "cpu" to cpu,
            "memory" to mem,
            "battery" to battery,
            "thermal" to thermal,
            "network" to net,
        )
    }

    private fun throughput(t: NetInfo.Traffic, now: Long): Map<String, Any?> {
        val prev = prevTraffic
        val dt = (now - prevTrafficAt) / 1000.0
        prevTraffic = t
        prevTrafficAt = now
        fun rate(cur: Long, old: Long): Double? =
            if (prev == null || dt <= 0 || cur < 0 || old < 0) null
            else ((cur - old) / dt).coerceAtLeast(0.0)
        return mapOf(
            "totalRx" to t.totalRx, "totalTx" to t.totalTx,
            "uidRx" to t.uidRx, "uidTx" to t.uidTx,
            "rxPerSec" to rate(t.totalRx, prev?.totalRx ?: -1),
            "txPerSec" to rate(t.totalTx, prev?.totalTx ?: -1),
            "uidRxPerSec" to rate(t.uidRx, prev?.uidRx ?: -1),
            "uidTxPerSec" to rate(t.uidTx, prev?.uidTx ?: -1),
            "supported" to (t.totalRx >= 0),
        )
    }

    private fun estimateRate(level: Int?, now: Long): Double? {
        if (level == null) return null
        val prevLevel = prevBatteryLevel
        if (prevLevel == null || prevLevel == level) {
            if (prevLevel == null) {
                prevBatteryLevel = level
                prevBatteryAt = now
            }
            return null
        }
        val hours = (now - prevBatteryAt) / 3_600_000.0
        prevBatteryLevel = level
        prevBatteryAt = now
        if (hours <= 0) return null
        return (level - prevLevel) / hours
    }

    private fun estimateMinutes(b: PowerInfo.BatterySnapshot, ratePerHour: Double?): Double? {
        val level = b.levelPercent ?: return null
        // Prefer the coulomb counter when the driver exposes it.
        val currentMa = b.currentMa
        val capacity = b.capacityMah
        if (currentMa != null && capacity != null && kotlin.math.abs(currentMa) > 1) {
            val remainingMah = if (b.charging) capacity * (100 - level) / 100.0 else capacity * level / 100.0
            return remainingMah / kotlin.math.abs(currentMa) * 60.0
        }
        if (ratePerHour == null || kotlin.math.abs(ratePerHour) < 0.01) return null
        val remaining = if (ratePerHour > 0) (100 - level) else level
        return remaining / kotlin.math.abs(ratePerHour) * 60.0
    }
}
