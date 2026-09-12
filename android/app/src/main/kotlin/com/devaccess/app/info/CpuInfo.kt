package com.devaccess.app.info

import android.os.Build
import com.devaccess.app.bridge.Field
import com.devaccess.app.info.BuildInfo.field
import com.devaccess.app.util.Sys
import java.io.File

/**
 * Appendix B — SoC/CPU. FR-MON-1 uses [cores] and [totalLoad] for the live view.
 *
 * Android 8+ progressively restricted /proc and /sys; every read here degrades to a
 * labelled "unavailable" rather than throwing (NFR-RELIABILITY-1).
 */
object CpuInfo {

    private const val CPU_ROOT = "/sys/devices/system/cpu"

    data class Core(
        val index: Int,
        val curKHz: Long?,
        val minKHz: Long?,
        val maxKHz: Long?,
        val governor: String?,
        val online: Boolean,
        val loadPercent: Double?,
    ) {
        fun toMap(): Map<String, Any?> = mapOf(
            "index" to index, "cur" to curKHz, "min" to minKHz, "max" to maxKHz,
            "governor" to governor, "online" to online, "load" to loadPercent,
        )
    }

    fun coreCount(): Int = try {
        Runtime.getRuntime().availableProcessors()
    } catch (t: Throwable) {
        1
    }

    /** Physical core directories, which can exceed [coreCount] when cores are hot-unplugged. */
    private fun coreDirs(): List<File> =
        Sys.listDir(CPU_ROOT, "cpu").filter { it.name.matches(Regex("cpu\\d+")) }

    fun cores(withLoad: Boolean): List<Core> {
        val load = if (withLoad) sampleLoad() else emptyMap()
        val dirs = coreDirs().ifEmpty { (0 until coreCount()).map { File("$CPU_ROOT/cpu$it") } }
        return dirs.mapNotNull { dir ->
            val idx = dir.name.removePrefix("cpu").toIntOrNull() ?: return@mapNotNull null
            val f = "${dir.absolutePath}/cpufreq"
            Core(
                index = idx,
                curKHz = Sys.readLong("$f/scaling_cur_freq") ?: Sys.readLong("$f/cpuinfo_cur_freq"),
                minKHz = Sys.readLong("$f/cpuinfo_min_freq") ?: Sys.readLong("$f/scaling_min_freq"),
                maxKHz = Sys.readLong("$f/cpuinfo_max_freq") ?: Sys.readLong("$f/scaling_max_freq"),
                governor = Sys.readFile("$f/scaling_governor"),
                online = Sys.readFile("${dir.absolutePath}/online")?.trim() != "0",
                loadPercent = load["cpu$idx"],
            )
        }
    }

    // /proc/stat deltas. Two samples 250 ms apart give a usable instantaneous load.
    private var lastStat: Map<String, Pair<Long, Long>> = emptyMap()

    private fun readStat(): Map<String, Pair<Long, Long>> = try {
        val map = mutableMapOf<String, Pair<Long, Long>>()
        File("/proc/stat").forEachLine { line ->
            if (line.startsWith("cpu")) {
                val parts = line.trim().split(Regex("\\s+"))
                val name = parts[0]
                val nums = parts.drop(1).mapNotNull { it.toLongOrNull() }
                if (nums.size >= 4) {
                    val total = nums.sum()
                    val idle = nums[3] + (nums.getOrNull(4) ?: 0L)
                    map[name] = total to idle
                }
            }
        }
        map
    } catch (t: Throwable) {
        emptyMap()
    }

    /** Percentage busy per core key ("cpu", "cpu0", …) since the previous call. */
    fun sampleLoad(): Map<String, Double> {
        val now = readStat()
        if (now.isEmpty()) return emptyMap()
        val prev = lastStat
        lastStat = now
        if (prev.isEmpty()) return emptyMap()
        return now.mapNotNull { (k, cur) ->
            val old = prev[k] ?: return@mapNotNull null
            val dTotal = cur.first - old.first
            val dIdle = cur.second - old.second
            if (dTotal <= 0) null else k to ((dTotal - dIdle) * 100.0 / dTotal).coerceIn(0.0, 100.0)
        }.toMap()
    }

    fun totalLoad(): Double? = sampleLoad()["cpu"]

    /** big.LITTLE style clustering, derived from max frequency groups. */
    fun clusters(cores: List<Core>): List<Map<String, Any?>> =
        cores.filter { it.maxKHz != null }
            .groupBy { it.maxKHz }
            .toSortedMap(compareByDescending { it })
            .map { (maxKHz, group) ->
                mapOf(
                    "maxKHz" to maxKHz,
                    "cores" to group.map { it.index },
                    "count" to group.size,
                    "label" to "${group.size}× @ %.2f GHz".format((maxKHz ?: 0L) / 1_000_000.0),
                )
            }

    private fun cpuinfoValue(vararg keys: String): String? {
        val text = Sys.readFile("/proc/cpuinfo") ?: return null
        for (line in text.lineSequence()) {
            val idx = line.indexOf(':')
            if (idx <= 0) continue
            val k = line.substring(0, idx).trim()
            if (keys.any { it.equals(k, ignoreCase = true) }) {
                return line.substring(idx + 1).trim().takeIf { it.isNotEmpty() }
            }
        }
        return null
    }

    fun fields(): List<Map<String, Any?>> {
        val cores = cores(withLoad = false)
        return listOf(
            field("socName", "SoC / chipset", socName()),
            field("arch", "Architecture", Field.of { System.getProperty("os.arch") }),
            field("abis", "Supported ABIs", Field.of { Build.SUPPORTED_ABIS.joinToString(", ") }),
            field("abis64", "64-bit ABIs", Field.of {
                Build.SUPPORTED_64_BIT_ABIS.joinToString(", ").ifEmpty { "none" }
            }),
            field("abis32", "32-bit ABIs", Field.of {
                Build.SUPPORTED_32_BIT_ABIS.joinToString(", ").ifEmpty { "none" }
            }),
            field("coreCount", "Core count", Field.ok(coreCount())),
            field("coreDirs", "Cores exposed in sysfs", Field.ok(cores.size)),
            field("governor", "Governor", cores.firstOrNull()?.governor?.let { Field.ok(it) }
                ?: Field.restricted("scaling_governor is not readable by unprivileged apps on this build")),
            field("clusters", "Cluster topology", if (cores.any { it.maxKHz != null }) {
                Field.ok(clusters(cores).joinToString(" + ") { it["label"] as String })
            } else {
                Field.restricted("cpufreq nodes are not readable by unprivileged apps on this build")
            }),
            field("perCore", "Per-core frequency", if (cores.any { it.maxKHz != null }) {
                Field.ok(cores.joinToString("\n") { c ->
                    "cpu${c.index}: " + listOfNotNull(
                        c.curKHz?.let { "cur %.0f MHz".format(it / 1000.0) },
                        c.minKHz?.let { "min %.0f MHz".format(it / 1000.0) },
                        c.maxKHz?.let { "max %.0f MHz".format(it / 1000.0) },
                    ).joinToString(" · ").ifEmpty { "no cpufreq nodes" }
                })
            } else {
                Field.restricted("Per-core cpufreq is not readable by unprivileged apps on this build")
            }),
            field("hardware", "cpuinfo Hardware", Field.of {
                cpuinfoValue("Hardware", "model name", "Processor")
            }),
            field("features", "CPU features", Field.of { cpuinfoValue("Features", "flags") }),
            field("implementer", "CPU implementer", Field.of { cpuinfoValue("CPU implementer") }),
            field("part", "CPU part", Field.of { cpuinfoValue("CPU part") }),
        )
    }

    private fun socName(): Map<String, Any?> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val m = Build.SOC_MANUFACTURER.takeIf { it != Build.UNKNOWN }
            val model = Build.SOC_MODEL.takeIf { it != Build.UNKNOWN }
            if (m != null || model != null) {
                return Field.ok(listOfNotNull(m, model).joinToString(" "))
            }
        }
        val fallback = listOfNotNull(
            Sys.prop("ro.soc.manufacturer"),
            Sys.prop("ro.soc.model") ?: Sys.prop("ro.board.platform") ?: Sys.prop("ro.hardware.chipname"),
        ).joinToString(" ").ifBlank { null }
            ?: cpuinfoValue("Hardware")
            ?: Build.HARDWARE.takeIf { it.isNotBlank() }
        return fallback?.let { Field.ok(it) }
            ?: Field.restricted("SoC name is not exposed on this build (Build.SOC_MODEL needs API 31+)")
    }
}
