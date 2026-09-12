package com.devaccess.app.info

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import com.devaccess.app.bridge.Field
import com.devaccess.app.info.BuildInfo.field

/** FR-SEN-1 — full sensor enumeration with metadata. */
object SensorInfo {

    fun sensors(context: Context): List<Map<String, Any?>> {
        val sm = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
            ?: return emptyList()
        return sm.getSensorList(Sensor.TYPE_ALL).map { s ->
            mapOf(
                "name" to s.name,
                "vendor" to s.vendor,
                "type" to s.type,
                "typeName" to typeName(s),
                "stringType" to s.stringType,
                "version" to s.version,
                "resolution" to s.resolution,
                "maxRange" to s.maximumRange,
                "power" to s.power,
                "minDelay" to s.minDelay,
                "maxDelay" to s.maxDelay,
                "maxRate" to if (s.minDelay > 0) 1_000_000f / s.minDelay else null,
                "reportingMode" to reportingMode(s.reportingMode),
                "wakeUp" to s.isWakeUpSensor,
                "dynamic" to s.isDynamicSensor,
                "fifoMax" to s.fifoMaxEventCount,
                "fifoReserved" to s.fifoReservedEventCount,
                "id" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    try { s.id } catch (t: Throwable) { null }
                } else null,
                "valueCount" to valueCount(s.type),
                "unit" to unit(s.type),
                "axes" to axisLabels(s.type),
                "selfTest" to selfTestHint(s.type),
            )
        }.sortedBy { it["typeName"] as String }
    }

    fun fields(context: Context): List<Map<String, Any?>> {
        val list = sensors(context)
        if (list.isEmpty()) {
            return listOf(field("sensors", "Sensors", Field.unavailable("No SensorManager or no sensors reported")))
        }
        val out = mutableListOf<Map<String, Any?>>()
        out += field("count", "Sensor count", Field.ok(list.size))
        out += field("wakeUp", "Wake-up sensors", Field.ok(list.count { it["wakeUp"] == true }))
        list.forEachIndexed { i, s ->
            out += field(
                "sensor$i", "${s["typeName"]} — ${s["name"]}",
                Field.ok(
                    buildString {
                        append("vendor ").append(s["vendor"])
                        append(" · v").append(s["version"])
                        append(" · range ").append(s["maxRange"]).append(" ").append(s["unit"])
                        append(" · res ").append(s["resolution"])
                        append(" · ").append(s["power"]).append(" mA")
                        append(" · min delay ").append(s["minDelay"]).append(" µs")
                        append(" · ").append(s["reportingMode"])
                    },
                ),
            )
        }
        return out
    }

    private fun reportingMode(mode: Int): String = when (mode) {
        Sensor.REPORTING_MODE_CONTINUOUS -> "continuous"
        Sensor.REPORTING_MODE_ON_CHANGE -> "on-change"
        Sensor.REPORTING_MODE_ONE_SHOT -> "one-shot"
        Sensor.REPORTING_MODE_SPECIAL_TRIGGER -> "special-trigger"
        else -> "unknown"
    }

    fun typeName(s: Sensor): String = when (s.type) {
        Sensor.TYPE_ACCELEROMETER -> "Accelerometer"
        Sensor.TYPE_MAGNETIC_FIELD -> "Magnetometer"
        Sensor.TYPE_GYROSCOPE -> "Gyroscope"
        Sensor.TYPE_LIGHT -> "Light"
        Sensor.TYPE_PRESSURE -> "Pressure"
        Sensor.TYPE_PROXIMITY -> "Proximity"
        Sensor.TYPE_GRAVITY -> "Gravity"
        Sensor.TYPE_LINEAR_ACCELERATION -> "Linear acceleration"
        Sensor.TYPE_ROTATION_VECTOR -> "Rotation vector"
        Sensor.TYPE_RELATIVE_HUMIDITY -> "Relative humidity"
        Sensor.TYPE_AMBIENT_TEMPERATURE -> "Ambient temperature"
        Sensor.TYPE_MAGNETIC_FIELD_UNCALIBRATED -> "Magnetometer (uncal.)"
        Sensor.TYPE_GAME_ROTATION_VECTOR -> "Game rotation vector"
        Sensor.TYPE_GYROSCOPE_UNCALIBRATED -> "Gyroscope (uncal.)"
        Sensor.TYPE_SIGNIFICANT_MOTION -> "Significant motion"
        Sensor.TYPE_STEP_DETECTOR -> "Step detector"
        Sensor.TYPE_STEP_COUNTER -> "Step counter"
        Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR -> "Geomagnetic rotation vector"
        Sensor.TYPE_HEART_RATE -> "Heart rate"
        Sensor.TYPE_POSE_6DOF -> "Pose 6DOF"
        Sensor.TYPE_STATIONARY_DETECT -> "Stationary detect"
        Sensor.TYPE_MOTION_DETECT -> "Motion detect"
        Sensor.TYPE_HEART_BEAT -> "Heart beat"
        Sensor.TYPE_LOW_LATENCY_OFFBODY_DETECT -> "Off-body detect"
        Sensor.TYPE_ACCELEROMETER_UNCALIBRATED -> "Accelerometer (uncal.)"
        else -> s.stringType?.substringAfterLast('.')?.replace('_', ' ')
            ?.replaceFirstChar { it.uppercase() } ?: "Type ${s.type}"
    }

    private fun valueCount(type: Int): Int = when (type) {
        Sensor.TYPE_ACCELEROMETER, Sensor.TYPE_MAGNETIC_FIELD, Sensor.TYPE_GYROSCOPE,
        Sensor.TYPE_GRAVITY, Sensor.TYPE_LINEAR_ACCELERATION,
        -> 3
        Sensor.TYPE_ROTATION_VECTOR, Sensor.TYPE_GAME_ROTATION_VECTOR,
        Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR,
        -> 4
        Sensor.TYPE_MAGNETIC_FIELD_UNCALIBRATED, Sensor.TYPE_GYROSCOPE_UNCALIBRATED,
        Sensor.TYPE_ACCELEROMETER_UNCALIBRATED,
        -> 6
        Sensor.TYPE_POSE_6DOF -> 15
        else -> 1
    }

    private fun unit(type: Int): String = when (type) {
        Sensor.TYPE_ACCELEROMETER, Sensor.TYPE_GRAVITY, Sensor.TYPE_LINEAR_ACCELERATION,
        Sensor.TYPE_ACCELEROMETER_UNCALIBRATED,
        -> "m/s²"
        Sensor.TYPE_MAGNETIC_FIELD, Sensor.TYPE_MAGNETIC_FIELD_UNCALIBRATED -> "µT"
        Sensor.TYPE_GYROSCOPE, Sensor.TYPE_GYROSCOPE_UNCALIBRATED -> "rad/s"
        Sensor.TYPE_LIGHT -> "lx"
        Sensor.TYPE_PRESSURE -> "hPa"
        Sensor.TYPE_PROXIMITY -> "cm"
        Sensor.TYPE_RELATIVE_HUMIDITY -> "%"
        Sensor.TYPE_AMBIENT_TEMPERATURE -> "°C"
        Sensor.TYPE_HEART_RATE -> "bpm"
        Sensor.TYPE_STEP_COUNTER -> "steps"
        else -> ""
    }

    private fun axisLabels(type: Int): List<String> = when (valueCount(type)) {
        3 -> listOf("X", "Y", "Z")
        4 -> listOf("X", "Y", "Z", "W")
        6 -> listOf("X", "Y", "Z", "bX", "bY", "bZ")
        1 -> listOf("value")
        else -> (0 until valueCount(type)).map { "v$it" }
    }

    /** FR-SEN-3 — the instruction shown by the self-test runner, and how it is judged. */
    private fun selfTestHint(type: Int): Map<String, Any?>? = when (type) {
        Sensor.TYPE_ACCELEROMETER, Sensor.TYPE_LINEAR_ACCELERATION, Sensor.TYPE_GYROSCOPE,
        Sensor.TYPE_MAGNETIC_FIELD, Sensor.TYPE_GRAVITY, Sensor.TYPE_ROTATION_VECTOR,
        -> mapOf(
            "instruction" to "Move and rotate the device for a few seconds.",
            "mode" to "variance",
            "threshold" to 0.5,
            "seconds" to 6,
        )
        Sensor.TYPE_PROXIMITY -> mapOf(
            "instruction" to "Cover the proximity sensor with your hand, then uncover it.",
            "mode" to "range",
            "threshold" to 0.5,
            "seconds" to 8,
        )
        Sensor.TYPE_LIGHT -> mapOf(
            "instruction" to "Cover the light sensor, then expose it to a bright light.",
            "mode" to "range",
            "threshold" to 10.0,
            "seconds" to 8,
        )
        Sensor.TYPE_PRESSURE -> mapOf(
            "instruction" to "Hold still — the reading should settle near local air pressure (~1013 hPa).",
            "mode" to "present",
            "threshold" to 0.0,
            "seconds" to 5,
        )
        Sensor.TYPE_STEP_COUNTER, Sensor.TYPE_STEP_DETECTOR -> mapOf(
            "instruction" to "Walk a few steps holding the device.",
            "mode" to "range",
            "threshold" to 0.5,
            "seconds" to 15,
        )
        Sensor.TYPE_AMBIENT_TEMPERATURE, Sensor.TYPE_RELATIVE_HUMIDITY -> mapOf(
            "instruction" to "Hold still and wait for a reading.",
            "mode" to "present",
            "threshold" to 0.0,
            "seconds" to 6,
        )
        else -> null
    }
}
