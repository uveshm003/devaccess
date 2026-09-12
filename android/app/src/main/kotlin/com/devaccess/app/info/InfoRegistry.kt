package com.devaccess.app.info

import android.content.Context

/**
 * FR-INFO-1 — the fourteen dashboard sections.
 *
 * Sections are resolved one at a time so the UI can render progressively (NFR-PERF-1):
 * cheap sections (Device & Build) return immediately while GPU or Cameras are still loading.
 */
object InfoRegistry {

    data class Section(
        val id: String,
        val title: String,
        val live: Boolean,
        val provider: (Context) -> List<Map<String, Any?>>,
    )

    val sections: List<Section> = listOf(
        Section("device", "Device & Build", false) { BuildInfo.deviceAndBuild(it) },
        Section("os", "OS & Security", false) { BuildInfo.osAndSecurity(it) },
        Section("display", "Display", false) { DisplayInfo.fields(it) },
        Section("cpu", "SoC / CPU", false) { CpuInfo.fields() },
        Section("gpu", "GPU", false) { GpuInfo.fields(it) },
        Section("memory", "Memory", true) { MemoryStorageInfo.memoryFields(it) },
        Section("storage", "Storage", false) { MemoryStorageInfo.storageFields(it) },
        Section("battery", "Battery", true) { PowerInfo.batteryFields(it) },
        Section("thermal", "Thermal", true) { PowerInfo.thermalFields(it) },
        Section("network", "Network", true) { NetInfo.networkFields(it) },
        Section("telephony", "Telephony", true) { NetInfo.telephonyFields(it) },
        Section("sensors", "Sensors", false) { SensorInfo.fields(it) },
        Section("cameras", "Cameras", false) { CameraInfo.fields(it) },
        Section("system", "System state", true) { BuildInfo.systemState(it) },
    )

    fun index(): List<Map<String, Any?>> = sections.map {
        mapOf("id" to it.id, "title" to it.title, "live" to it.live)
    }

    /** NFR-RELIABILITY-1 — a provider that blows up yields an error section, not a crash. */
    fun section(context: Context, id: String): Map<String, Any?> {
        val s = sections.firstOrNull { it.id == id }
            ?: return mapOf("id" to id, "title" to id, "live" to false, "fields" to emptyList<Any>(),
                "error" to "Unknown section '$id'")
        return try {
            mapOf("id" to s.id, "title" to s.title, "live" to s.live, "fields" to s.provider(context))
        } catch (t: Throwable) {
            mapOf(
                "id" to s.id, "title" to s.title, "live" to s.live,
                "fields" to emptyList<Any>(),
                "error" to "${t.javaClass.simpleName}: ${t.message}",
            )
        }
    }

    fun all(context: Context): List<Map<String, Any?>> = sections.map { section(context, it.id) }
}
