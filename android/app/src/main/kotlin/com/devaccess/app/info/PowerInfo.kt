package com.devaccess.app.info

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import com.devaccess.app.bridge.Field
import com.devaccess.app.info.BuildInfo.field
import com.devaccess.app.util.Sys
import java.io.File

/** Appendix B — Battery and Thermal. FR-MON-3 / FR-MON-4 use [batterySnapshot] / [thermalSnapshot]. */
object PowerInfo {

    data class BatterySnapshot(
        val levelPercent: Int?,
        val status: String,
        val charging: Boolean,
        val health: String,
        val plugged: String,
        val technology: String?,
        val temperatureC: Double?,
        val voltageV: Double?,
        val currentMa: Double?,
        val chargeCounterMah: Double?,
        val capacityMah: Double?,
        val cycleCount: Int?,
        val energyWh: Double?,
    ) {
        fun toMap(): Map<String, Any?> = mapOf(
            "level" to levelPercent, "status" to status, "charging" to charging,
            "health" to health, "plugged" to plugged, "technology" to technology,
            "temperature" to temperatureC, "voltage" to voltageV, "current" to currentMa,
            "chargeCounter" to chargeCounterMah, "capacity" to capacityMah,
            "cycleCount" to cycleCount, "energy" to energyWh,
        )
    }

    @Suppress("DEPRECATION")
    fun batterySnapshot(context: Context): BatterySnapshot {
        val intent: Intent? = try {
            context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        } catch (t: Throwable) {
            null
        }
        val bm = try {
            context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        } catch (t: Throwable) {
            null
        }

        val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val percent = if (level >= 0 && scale > 0) level * 100 / scale else null

        val statusInt = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val status = when (statusInt) {
            BatteryManager.BATTERY_STATUS_CHARGING -> "Charging"
            BatteryManager.BATTERY_STATUS_DISCHARGING -> "Discharging"
            BatteryManager.BATTERY_STATUS_FULL -> "Full"
            BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "Not charging"
            else -> "Unknown"
        }
        val healthInt = intent?.getIntExtra(BatteryManager.EXTRA_HEALTH, -1) ?: -1
        val health = when (healthInt) {
            BatteryManager.BATTERY_HEALTH_GOOD -> "Good"
            BatteryManager.BATTERY_HEALTH_OVERHEAT -> "Overheat"
            BatteryManager.BATTERY_HEALTH_DEAD -> "Dead"
            BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "Over voltage"
            BatteryManager.BATTERY_HEALTH_COLD -> "Cold"
            BatteryManager.BATTERY_HEALTH_UNSPECIFIED_FAILURE -> "Unspecified failure"
            else -> "Unknown"
        }
        val pluggedInt = intent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
        val plugged = when (pluggedInt) {
            BatteryManager.BATTERY_PLUGGED_AC -> "AC"
            BatteryManager.BATTERY_PLUGGED_USB -> "USB"
            BatteryManager.BATTERY_PLUGGED_WIRELESS -> "Wireless"
            5 -> "Dock" // BATTERY_PLUGGED_DOCK, API 34
            0 -> "Unplugged"
            else -> "Plugged ($pluggedInt)"
        }

        val tempTenths = intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
        val mv = intent?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, Int.MIN_VALUE)

        // Unsupported properties come back as Long.MIN_VALUE (and, on some drivers, 0).
        fun prop(id: Int, zeroIsValid: Boolean = false): Long? = try {
            bm?.getLongProperty(id)?.takeIf { it != Long.MIN_VALUE && (zeroIsValid || it != 0L) }
        } catch (t: Throwable) {
            null
        }

        // BATTERY_PROPERTY_CURRENT_NOW is in µA and its sign convention is OEM-dependent.
        // Zero is a genuine reading here (an idle battery), so it is kept.
        val currentUa = prop(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW, zeroIsValid = true)
        val chargeUah = prop(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
        val energyNwh = prop(BatteryManager.BATTERY_PROPERTY_ENERGY_COUNTER)

        return BatterySnapshot(
            levelPercent = percent,
            status = status,
            charging = statusInt == BatteryManager.BATTERY_STATUS_CHARGING ||
                statusInt == BatteryManager.BATTERY_STATUS_FULL,
            health = health,
            plugged = plugged,
            technology = intent?.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY),
            temperatureC = tempTenths?.takeIf { it != Int.MIN_VALUE && it != 0 }?.let { it / 10.0 },
            voltageV = mv?.takeIf { it != Int.MIN_VALUE && it > 0 }?.let { it / 1000.0 },
            currentMa = currentUa?.let { it / 1000.0 },
            chargeCounterMah = chargeUah?.let { it / 1000.0 },
            capacityMah = designCapacityMah(context),
            cycleCount = cycleCount(intent),
            energyWh = energyNwh?.let { it / 1_000_000_000.0 },
        )
    }

    /**
     * Design capacity is not part of the public API. The framework value lives in a hidden
     * `com.android.internal.os.PowerProfile` resource; sysfs sometimes exposes it too.
     */
    private fun designCapacityMah(context: Context): Double? {
        try {
            @Suppress("PrivateApi")
            val cls = Class.forName("com.android.internal.os.PowerProfile")
            val instance = cls.getConstructor(Context::class.java).newInstance(context)
            val v = cls.getMethod("getBatteryCapacity").invoke(instance) as? Double
            if (v != null && v > 0) return v
        } catch (t: Throwable) {
            // Hidden-API access is blocked from Android 9 onward on most builds.
        }
        listOf(
            "/sys/class/power_supply/battery/charge_full_design",
            "/sys/class/power_supply/bms/charge_full_design",
        ).forEach { p ->
            Sys.readLong(p)?.let { return if (it > 100000) it / 1000.0 else it.toDouble() }
        }
        return null
    }

    private fun cycleCount(intent: Intent?): Int? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            intent?.getIntExtra(BatteryManager.EXTRA_CYCLE_COUNT, -1)
                ?.takeIf { it >= 0 }?.let { return it }
        }
        return Sys.readLong("/sys/class/power_supply/battery/cycle_count")?.toInt()
    }

    fun batteryFields(context: Context): List<Map<String, Any?>> {
        val b = batterySnapshot(context)
        fun num(v: Any?, unit: String, missing: String) =
            if (v == null) Field.restricted(missing) else Field.ok("$v $unit")
        return listOf(
            field("level", "Level", b.levelPercent?.let { Field.ok("$it %") }
                ?: Field.unavailable("ACTION_BATTERY_CHANGED returned no level")),
            field("status", "Status", Field.ok(b.status)),
            field("health", "Health", Field.ok(b.health)),
            field("plugged", "Power source", Field.ok(b.plugged)),
            field("technology", "Technology", b.technology?.let { Field.ok(it) }
                ?: Field.unavailable("Not reported by the battery driver")),
            field("temperature", "Temperature", b.temperatureC?.let { Field.ok("%.1f °C".format(it)) }
                ?: Field.unavailable("Not reported by the battery driver")),
            field("voltage", "Voltage", b.voltageV?.let { Field.ok("%.3f V".format(it)) }
                ?: Field.unavailable("Not reported by the battery driver")),
            field("current", "Current now", b.currentMa?.let { Field.ok("%.0f mA".format(it)) }
                ?: Field.unavailable("BATTERY_PROPERTY_CURRENT_NOW is not implemented on this device")),
            field("chargeCounter", "Charge counter", b.chargeCounterMah?.let { Field.ok("%.0f mAh".format(it)) }
                ?: Field.unavailable("BATTERY_PROPERTY_CHARGE_COUNTER is not implemented on this device")),
            field("capacity", "Design capacity", b.capacityMah?.let { Field.ok("%.0f mAh".format(it)) }
                ?: Field.restricted("Design capacity lives in a hidden framework resource; blocked for normal apps")),
            field("cycleCount", "Cycle count", b.cycleCount?.let { Field.ok(it) }
                ?: Field.restricted("Cycle count needs Android 14 (API 34) or a readable sysfs node")),
            field("energy", "Energy counter", b.energyWh?.let { Field.ok("%.2f Wh".format(it)) }
                ?: Field.unavailable("BATTERY_PROPERTY_ENERGY_COUNTER is not implemented on this device")),
            field("saver", "Battery saver", Field.of {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                pm.isPowerSaveMode
            }),
        )
    }

    // ---- thermal ----------------------------------------------------------

    data class ThermalZone(val name: String, val type: String, val celsius: Double)

    data class ThermalSnapshot(
        val statusCode: Int?,
        val statusLabel: String,
        val zones: List<ThermalZone>,
        val zonesReason: String?,
    ) {
        fun toMap(): Map<String, Any?> = mapOf(
            "status" to statusCode,
            "statusLabel" to statusLabel,
            "zones" to zones.map { mapOf("name" to it.name, "type" to it.type, "celsius" to it.celsius) },
            "zonesReason" to zonesReason,
        )
    }

    fun thermalSnapshot(context: Context): ThermalSnapshot {
        var code: Int? = null
        var label = "Requires Android 10 (API 29)"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                code = pm.currentThermalStatus
                label = thermalLabel(code)
            } catch (t: Throwable) {
                label = "PowerManager.getCurrentThermalStatus failed"
            }
        }
        val zones = readZones()
        return ThermalSnapshot(
            statusCode = code,
            statusLabel = label,
            zones = zones,
            zonesReason = if (zones.isEmpty()) {
                "/sys/class/thermal is not readable by unprivileged apps on this build"
            } else {
                null
            },
        )
    }

    fun thermalLabel(code: Int): String = when (code) {
        PowerManager.THERMAL_STATUS_NONE -> "None"
        PowerManager.THERMAL_STATUS_LIGHT -> "Light"
        PowerManager.THERMAL_STATUS_MODERATE -> "Moderate"
        PowerManager.THERMAL_STATUS_SEVERE -> "Severe"
        PowerManager.THERMAL_STATUS_CRITICAL -> "Critical"
        PowerManager.THERMAL_STATUS_EMERGENCY -> "Emergency"
        PowerManager.THERMAL_STATUS_SHUTDOWN -> "Shutdown"
        else -> "Unknown ($code)"
    }

    private fun readZones(): List<ThermalZone> = try {
        File("/sys/class/thermal").listFiles { f -> f.name.startsWith("thermal_zone") }
            ?.sortedBy { it.name.removePrefix("thermal_zone").toIntOrNull() ?: 0 }
            ?.mapNotNull { dir ->
                val raw = Sys.readLong("${dir.absolutePath}/temp") ?: return@mapNotNull null
                // Drivers report milli-°C, deci-°C or °C depending on vendor.
                val c = when {
                    kotlin.math.abs(raw) > 10_000 -> raw / 1000.0
                    kotlin.math.abs(raw) > 1_000 -> raw / 100.0
                    kotlin.math.abs(raw) > 200 -> raw / 10.0
                    else -> raw.toDouble()
                }
                if (c < -50 || c > 200) return@mapNotNull null
                ThermalZone(
                    name = dir.name,
                    type = Sys.readFile("${dir.absolutePath}/type") ?: "unknown",
                    celsius = c,
                )
            } ?: emptyList()
    } catch (t: Throwable) {
        emptyList()
    }

    fun thermalFields(context: Context): List<Map<String, Any?>> {
        val t = thermalSnapshot(context)
        val list = mutableListOf<Map<String, Any?>>()
        list += field("status", "Thermal status",
            if (t.statusCode != null) Field.ok(t.statusLabel) else Field.restricted(t.statusLabel))
        list += field("zoneCount", "Readable thermal zones",
            if (t.zones.isNotEmpty()) Field.ok(t.zones.size) else Field.restricted(t.zonesReason!!))
        t.zones.forEach { z ->
            list += field("zone_${z.name}", "${z.name} (${z.type})", Field.ok("%.1f °C".format(z.celsius)))
        }
        return list
    }
}
