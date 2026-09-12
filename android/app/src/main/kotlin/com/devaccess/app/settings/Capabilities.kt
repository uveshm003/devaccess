package com.devaccess.app.settings

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import com.devaccess.app.BuildConfig
import com.devaccess.app.security.RootShell

/**
 * Section 5 — resolves the highest access tier available right now.
 *
 *  T0 base            — always.
 *  T1 WRITE_SETTINGS  — special access the user grants from Settings (C3).
 *  T2 WRITE_SECURE_SETTINGS — granted only over adb / privileged signature (C1).
 *  T3 root            — `su` answers with uid 0.
 */
object Capabilities {

    const val T0 = 0
    const val T1 = 1
    const val T2 = 2
    const val T3 = 3

    fun canWriteSystem(context: Context): Boolean = try {
        Settings.System.canWrite(context)
    } catch (t: Throwable) {
        false
    }

    fun canWriteSecure(context: Context): Boolean = try {
        context.checkSelfPermission(Manifest.permission.WRITE_SECURE_SETTINGS) ==
            PackageManager.PERMISSION_GRANTED
    } catch (t: Throwable) {
        false
    }

    fun canDump(context: Context): Boolean = try {
        context.checkSelfPermission(Manifest.permission.DUMP) == PackageManager.PERMISSION_GRANTED
    } catch (t: Throwable) {
        false
    }

    fun tier(context: Context, probeRoot: Boolean): Int = when {
        RootShell.hasRoot(probeRoot) -> T3
        canWriteSecure(context) -> T2
        canWriteSystem(context) -> T1
        else -> T0
    }

    /** FR-TIER-1 / FR-TIER-2 — everything the tier screen and the unlock wizard need. */
    fun status(context: Context, probeRoot: Boolean): Map<String, Any?> {
        val pkg = context.packageName
        val root = RootShell.hasRoot(probeRoot)
        val secure = canWriteSecure(context)
        val system = canWriteSystem(context)
        return mapOf(
            "tier" to tier(context, probeRoot),
            "writeSettings" to system,
            "writeSecureSettings" to secure,
            "root" to root,
            "rootProbed" to (RootShell.cachedRoot() != null),
            "suBinary" to RootShell.suBinary(),
            "magiskArtifacts" to RootShell.magiskArtifacts(),
            "buildSignals" to RootShell.buildSignals(),
            "dump" to canDump(context),
            "packageName" to pkg,
            "adbCommand" to "adb shell pm grant $pkg ${Manifest.permission.WRITE_SECURE_SETTINGS}",
            "adbDumpCommand" to "adb shell pm grant $pkg ${Manifest.permission.DUMP}",
            "adbLogsCommand" to "adb shell pm grant $pkg android.permission.READ_LOGS",
            "wirelessDebuggingSupported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R),
            "sdkInt" to Build.VERSION.SDK_INT,
            "flavor" to BuildConfig.DISTRIBUTION,
            "fullAccessBuild" to BuildConfig.FULL_ACCESS,
        )
    }
}
