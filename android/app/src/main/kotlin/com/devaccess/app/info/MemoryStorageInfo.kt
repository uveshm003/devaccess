package com.devaccess.app.info

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.Debug
import android.os.Environment
import android.os.StatFs
import android.os.storage.StorageManager
import com.devaccess.app.bridge.Field
import com.devaccess.app.info.BuildInfo.field
import com.devaccess.app.util.Sys
import java.io.File

/** Appendix B — Memory and Storage. FR-MON-2 uses [snapshot]. */
object MemoryStorageInfo {

    data class MemSnapshot(
        val totalBytes: Long,
        val availBytes: Long,
        val thresholdBytes: Long,
        val lowMemory: Boolean,
        val selfPssKb: Long,
    ) {
        val usedBytes: Long get() = (totalBytes - availBytes).coerceAtLeast(0)
        fun toMap(): Map<String, Any?> = mapOf(
            "total" to totalBytes, "available" to availBytes, "used" to usedBytes,
            "threshold" to thresholdBytes, "lowMemory" to lowMemory, "selfPssKb" to selfPssKb,
        )
    }

    fun snapshot(context: Context): MemSnapshot {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val mi = ActivityManager.MemoryInfo()
        am.getMemoryInfo(mi)
        val self = try {
            Debug.MemoryInfo().also { Debug.getMemoryInfo(it) }.totalPss.toLong()
        } catch (t: Throwable) {
            -1L
        }
        return MemSnapshot(mi.totalMem, mi.availMem, mi.threshold, mi.lowMemory, self)
    }

    fun memoryFields(context: Context): List<Map<String, Any?>> {
        val s = snapshot(context)
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return listOf(
            field("total", "Total RAM", Field.ok(s.totalBytes)),
            field("available", "Available RAM", Field.ok(s.availBytes)),
            field("used", "Used RAM", Field.ok(s.usedBytes)),
            field("threshold", "Low-memory threshold", Field.ok(s.thresholdBytes)),
            field("lowMemory", "Low-memory now", Field.ok(s.lowMemory)),
            field("lowRamDevice", "Is low-RAM device", Field.of { am.isLowRamDevice }),
            field("selfPss", "DevAccess PSS", if (s.selfPssKb >= 0) {
                Field.ok(s.selfPssKb * 1024)
            } else {
                Field.unavailable("Debug.getMemoryInfo failed")
            }),
            field("heapLimit", "App heap limit", Field.of { am.memoryClass * 1024L * 1024L }),
            field("largeHeapLimit", "Large heap limit", Field.of { am.largeMemoryClass * 1024L * 1024L }),
            field("swapTotal", "Swap total", meminfo("SwapTotal")),
            field("swapFree", "Swap free", meminfo("SwapFree")),
            field("zramTotal", "ZRAM disk size", Field.of {
                Sys.readLong("/sys/block/zram0/disksize")
            }),
        )
    }

    private fun meminfo(key: String): Map<String, Any?> {
        val text = Sys.readFile("/proc/meminfo")
            ?: return Field.restricted("/proc/meminfo is not readable on this build")
        val line = text.lineSequence().firstOrNull { it.startsWith("$key:") }
            ?: return Field.unavailable("$key not present in /proc/meminfo")
        val kb = line.split(Regex("\\s+")).getOrNull(1)?.toLongOrNull()
            ?: return Field.unavailable("Could not parse $key")
        return Field.ok(kb * 1024)
    }

    data class Volume(
        val label: String,
        val path: String?,
        val totalBytes: Long,
        val freeBytes: Long,
        val removable: Boolean,
        val emulated: Boolean,
        val primary: Boolean,
        val state: String,
    ) {
        fun toMap(): Map<String, Any?> = mapOf(
            "label" to label, "path" to path, "total" to totalBytes, "free" to freeBytes,
            "used" to (totalBytes - freeBytes).coerceAtLeast(0), "removable" to removable,
            "emulated" to emulated, "primary" to primary, "state" to state,
        )
    }

    fun volumes(context: Context): List<Volume> {
        val out = mutableListOf<Volume>()

        fun statOf(dir: File?): Pair<Long, Long>? = try {
            if (dir == null || !dir.exists()) null else {
                val fs = StatFs(dir.absolutePath)
                (fs.blockCountLong * fs.blockSizeLong) to (fs.availableBlocksLong * fs.blockSizeLong)
            }
        } catch (t: Throwable) {
            null
        }

        statOf(Environment.getDataDirectory())?.let { (t, f) ->
            out += Volume("Internal storage (data)", Environment.getDataDirectory().absolutePath, t, f,
                removable = false, emulated = true, primary = true, state = "mounted")
        }
        statOf(Environment.getRootDirectory())?.let { (t, f) ->
            out += Volume("System partition", Environment.getRootDirectory().absolutePath, t, f,
                removable = false, emulated = false, primary = false, state = "mounted read-only")
        }

        try {
            val sm = context.getSystemService(Context.STORAGE_SERVICE) as StorageManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                sm.storageVolumes.forEach { sv ->
                    val dir = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        sv.directory
                    } else {
                        null
                    }
                    val stat = statOf(dir)
                    out += Volume(
                        label = sv.getDescription(context) ?: "Volume",
                        path = dir?.absolutePath,
                        totalBytes = stat?.first ?: -1L,
                        freeBytes = stat?.second ?: -1L,
                        removable = sv.isRemovable,
                        emulated = sv.isEmulated,
                        primary = sv.isPrimary,
                        state = sv.state ?: "unknown",
                    )
                }
            }
        } catch (t: Throwable) {
            // StorageManager enumeration is best-effort.
        }

        // De-duplicate by resolved path, keeping the richest entry.
        return out.distinctBy { it.path ?: it.label }
    }

    fun storageFields(context: Context): List<Map<String, Any?>> {
        val vols = volumes(context)
        val internal = vols.firstOrNull { it.primary && !it.removable }
        val list = mutableListOf<Map<String, Any?>>()
        list += field("internalTotal", "Internal total",
            internal?.let { Field.ok(it.totalBytes) } ?: Field.unavailable("No primary volume"))
        list += field("internalFree", "Internal free",
            internal?.let { Field.ok(it.freeBytes) } ?: Field.unavailable("No primary volume"))
        list += field("volumeCount", "Volumes", Field.ok(vols.size))
        vols.forEachIndexed { i, v ->
            list += field(
                "vol$i", v.label,
                if (v.totalBytes >= 0) {
                    Field.ok(
                        "${human(v.freeBytes)} free of ${human(v.totalBytes)}" +
                            " · ${v.state}${if (v.removable) " · removable" else ""}",
                    )
                } else {
                    Field.restricted("Volume path is not readable by this app (scoped storage)")
                },
            )
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            list += field("allocatable", "Allocatable bytes", Field.of {
                val sm = context.getSystemService(Context.STORAGE_SERVICE) as StorageManager
                sm.getAllocatableBytes(sm.getUuidForPath(context.filesDir))
            })
        }
        return list
    }

    fun human(bytes: Long): String {
        if (bytes < 0) return "—"
        val units = arrayOf("B", "KiB", "MiB", "GiB", "TiB")
        var v = bytes.toDouble()
        var i = 0
        while (v >= 1024 && i < units.lastIndex) { v /= 1024; i++ }
        return if (i == 0) "$bytes B" else "%.2f %s".format(v, units[i])
    }
}
