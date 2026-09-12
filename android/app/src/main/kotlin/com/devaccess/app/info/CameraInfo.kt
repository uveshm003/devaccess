package com.devaccess.app.info

import android.content.Context
import android.graphics.ImageFormat
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.camera2.params.StreamConfigurationMap
import android.os.Build
import com.devaccess.app.bridge.Field
import com.devaccess.app.info.BuildInfo.field
import kotlin.math.roundToInt

/** Appendix B — Cameras. Reading characteristics needs no CAMERA permission. */
object CameraInfo {

    fun cameras(context: Context): List<Map<String, Any?>> {
        val cm = context.getSystemService(Context.CAMERA_SERVICE) as? CameraManager
            ?: return emptyList()
        return try {
            cm.cameraIdList.mapNotNull { id -> describe(cm, id) }
        } catch (t: Throwable) {
            emptyList()
        }
    }

    private fun describe(cm: CameraManager, id: String): Map<String, Any?>? = try {
        val c = cm.getCameraCharacteristics(id)
        val facing = when (c.get(CameraCharacteristics.LENS_FACING)) {
            CameraCharacteristics.LENS_FACING_FRONT -> "Front"
            CameraCharacteristics.LENS_FACING_BACK -> "Back"
            CameraCharacteristics.LENS_FACING_EXTERNAL -> "External"
            else -> "Unknown"
        }
        val map = c.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
        val sensorSize = c.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
        val pixelArray = c.get(CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE)

        mapOf(
            "id" to id,
            "facing" to facing,
            "megapixels" to pixelArray?.let {
                (it.width.toLong() * it.height / 1_000_000.0 * 10).roundToInt() / 10.0
            },
            "pixelArray" to pixelArray?.let { "${it.width} × ${it.height}" },
            "activeArray" to c.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)?.toString(),
            "sensorSize" to sensorSize?.let { "%.2f × %.2f mm".format(it.width, it.height) },
            "focalLengths" to c.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                ?.joinToString(", ") { "%.2f mm".format(it) },
            "apertures" to c.get(CameraCharacteristics.LENS_INFO_AVAILABLE_APERTURES)
                ?.joinToString(", ") { "ƒ/%.2f".format(it) },
            "flash" to (c.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) ?: false),
            "hardwareLevel" to hardwareLevel(c.get(CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL)),
            "orientation" to c.get(CameraCharacteristics.SENSOR_ORIENTATION),
            "maxZoom" to c.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM),
            "isoRange" to c.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)?.toString(),
            "exposureRange" to c.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE)
                ?.let { "${it.lower / 1000}µs – ${it.upper / 1_000_000}ms" },
            "afModes" to c.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES)?.size,
            "resolutions" to jpegSizes(map),
            "videoSizes" to videoSizes(map),
            "capabilities" to c.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)
                ?.joinToString(", ") { capability(it) },
            "physicalIds" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                c.physicalCameraIds.toList().takeIf { it.isNotEmpty() }
            } else null,
        )
    } catch (t: Throwable) {
        null
    }

    private fun jpegSizes(map: StreamConfigurationMap?): String? =
        map?.getOutputSizes(ImageFormat.JPEG)
            ?.sortedByDescending { it.width.toLong() * it.height }
            ?.take(8)
            ?.joinToString(", ") { "${it.width}×${it.height}" }

    private fun videoSizes(map: StreamConfigurationMap?): String? =
        map?.getOutputSizes(android.media.MediaRecorder::class.java)
            ?.sortedByDescending { it.width.toLong() * it.height }
            ?.take(6)
            ?.joinToString(", ") { "${it.width}×${it.height}" }

    private fun hardwareLevel(v: Int?): String = when (v) {
        CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_LEGACY -> "LEGACY"
        CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_LIMITED -> "LIMITED"
        CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_FULL -> "FULL"
        CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_3 -> "LEVEL_3"
        CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_EXTERNAL -> "EXTERNAL"
        else -> "unknown"
    }

    private fun capability(v: Int): String = when (v) {
        CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_BACKWARD_COMPATIBLE -> "backward-compatible"
        CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_SENSOR -> "manual-sensor"
        CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_POST_PROCESSING -> "manual-post"
        CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_RAW -> "raw"
        CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_BURST_CAPTURE -> "burst"
        CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_DEPTH_OUTPUT -> "depth"
        CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA -> "logical-multi"
        CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_MOTION_TRACKING -> "motion-tracking"
        CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_CONSTRAINED_HIGH_SPEED_VIDEO -> "high-speed-video"
        else -> "cap-$v"
    }

    fun fields(context: Context): List<Map<String, Any?>> {
        val cams = cameras(context)
        if (cams.isEmpty()) {
            return listOf(field("cameras", "Cameras", Field.unavailable(
                "No cameras enumerable — the device has none, or camera2 access is blocked",
            )))
        }
        val out = mutableListOf<Map<String, Any?>>()
        out += field("count", "Camera count", Field.ok(cams.size))
        cams.forEach { c ->
            out += field("cam${c["id"]}", "Camera ${c["id"]} (${c["facing"]})", Field.ok(
                buildString {
                    c["megapixels"]?.let { append(it).append(" MP · ") }
                    c["pixelArray"]?.let { append(it).append(" · ") }
                    append("level ").append(c["hardwareLevel"])
                    c["focalLengths"]?.let { append(" · ").append(it) }
                    c["apertures"]?.let { append(" · ").append(it) }
                    append(" · flash ").append(if (c["flash"] == true) "yes" else "no")
                    c["sensorSize"]?.let { append(" · sensor ").append(it) }
                    c["resolutions"]?.let { append("\nJPEG: ").append(it) }
                    c["videoSizes"]?.let { append("\nVideo: ").append(it) }
                    c["capabilities"]?.let { append("\nCaps: ").append(it) }
                },
            ))
        }
        return out
    }
}
