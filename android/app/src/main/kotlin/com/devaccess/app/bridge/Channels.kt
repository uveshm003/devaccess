package com.devaccess.app.bridge

/**
 * The complete platform-channel contract between the Flutter UI and the native layer.
 *
 * T-ARCH-1 — everything Dart cannot reach on its own (secure-settings writes, sensor
 * metadata, thermal API, per-core CPU, root/bootloader state, tiles, widgets) crosses
 * here. One request/response [io.flutter.plugin.common.MethodChannel] plus three
 * [io.flutter.plugin.common.EventChannel]s for the streaming surfaces.
 */
object Channels {
    const val METHOD = "dev.access/method"
    const val EVENT_MONITOR = "dev.access/events/monitor"
    const val EVENT_SENSORS = "dev.access/events/sensors"
    const val EVENT_NET = "dev.access/events/net"
}

/** Every value crossing the bridge is wrapped so the UI can tell *why* a field is empty. */
object Field {
    const val OK = "ok"
    const val RESTRICTED = "restricted"
    const val UNAVAILABLE = "unavailable"
    const val DENIED = "denied"

    fun ok(value: Any?): Map<String, Any?> = mapOf("v" to value, "s" to OK)

    /** FR-INFO-3 — the OS forbids this read on this API level. */
    fun restricted(reason: String): Map<String, Any?> =
        mapOf("v" to null, "s" to RESTRICTED, "r" to reason)

    /** NFR-RELIABILITY-1 — the read failed or the hardware does not exist. */
    fun unavailable(reason: String): Map<String, Any?> =
        mapOf("v" to null, "s" to UNAVAILABLE, "r" to reason)

    /** A runtime permission the user has not granted yet. */
    fun denied(reason: String): Map<String, Any?> =
        mapOf("v" to null, "s" to DENIED, "r" to reason)

    /**
     * NFR-RELIABILITY-1 — wraps a read that may throw anywhere in the platform.
     * A throwing provider yields an "unavailable" field, never a crash.
     */
    inline fun of(reason: String = "Read failed", block: () -> Any?): Map<String, Any?> = try {
        val v = block()
        if (v == null) unavailable(reason) else ok(v)
    } catch (t: Throwable) {
        unavailable(t.javaClass.simpleName + (t.message?.let { ": $it" } ?: ""))
    }
}
