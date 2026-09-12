package com.devaccess.app.security

import com.devaccess.app.util.Sys
import java.io.File

/**
 * T3 — root access. Detection is cached for the process lifetime because probing spawns
 * a `su` process and, on Magisk, may raise a grant prompt.
 */
object RootShell {

    private val SU_PATHS = listOf(
        "/system/bin/su", "/system/xbin/su", "/sbin/su", "/su/bin/su",
        "/system/sd/xbin/su", "/system/bin/failsafe/su", "/data/local/su",
        "/data/local/bin/su", "/data/local/xbin/su", "/vendor/bin/su",
        "/debug_ramdisk/su",
    )

    private val MAGISK_PATHS = listOf(
        "/sbin/magisk", "/data/adb/magisk", "/data/adb/modules",
        "/sbin/.magisk", "/cache/.disable_magisk", "/debug_ramdisk/magisk",
    )

    private val MANAGER_PACKAGES = listOf(
        "com.topjohnwu.magisk", "io.github.huskydg.magisk", "me.weishu.kernelsu",
        "com.rifsxd.ksunext", "eu.chainfire.supersu", "com.koushikdutta.superuser",
        "com.noshufou.android.su",
    )

    /** su binary present on disk — necessary but not sufficient for actual root. */
    fun suBinary(): String? = SU_PATHS.firstOrNull { File(it).exists() }

    fun magiskArtifacts(): List<String> = MAGISK_PATHS.filter { File(it).exists() }

    fun managerPackages(): List<String> = MANAGER_PACKAGES

    /** Dangerous-looking build signals that usually accompany a non-production image. */
    fun buildSignals(): List<String> {
        val out = mutableListOf<String>()
        if (android.os.Build.TAGS?.contains("test-keys") == true) out += "build tags: test-keys"
        if (Sys.prop("ro.debuggable") == "1") out += "ro.debuggable=1"
        if (Sys.prop("ro.secure") == "0") out += "ro.secure=0"
        if (Sys.prop("service.adb.root") == "1") out += "service.adb.root=1"
        return out
    }

    @Volatile private var granted: Boolean? = null

    /** True only if `su -c id` actually returns uid 0. Result is cached. */
    fun hasRoot(probe: Boolean): Boolean {
        granted?.let { return it }
        if (!probe) return false
        if (suBinary() == null && magiskArtifacts().isEmpty()) {
            granted = false
            return false
        }
        val r = Sys.exec(listOf("su", "-c", "id"), 4000)
        val ok = r.ok && r.stdout.contains("uid=0")
        granted = ok
        return ok
    }

    fun cachedRoot(): Boolean? = granted

    fun resetCache() { granted = null }

    /** Runs a command as root. Callers must have verified [hasRoot] first. */
    fun exec(command: String, timeoutMs: Long = 6000): Sys.ExecResult =
        Sys.exec(listOf("su", "-c", command), timeoutMs)
}
