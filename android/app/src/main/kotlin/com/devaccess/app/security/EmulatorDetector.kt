package com.devaccess.app.security

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import com.devaccess.app.util.Sys
import java.io.File

/** FR-INFO-6 — heuristic emulator / virtual-device detection. */
object EmulatorDetector {

    data class Result(val isEmulator: Boolean, val signals: List<String>)

    fun detect(context: Context): Result {
        val signals = mutableListOf<String>()

        fun flag(condition: Boolean, why: String) { if (condition) signals += why }

        val fp = Build.FINGERPRINT.orEmpty()
        flag(fp.startsWith("generic") || fp.startsWith("unknown"), "fingerprint starts with generic/unknown")
        flag(fp.contains("vbox") || fp.contains("test-keys") && fp.contains("generic"), "fingerprint mentions vbox")
        flag(Build.MODEL.contains("google_sdk", true), "model: google_sdk")
        flag(Build.MODEL.contains("Emulator", true), "model mentions Emulator")
        flag(Build.MODEL.contains("Android SDK built for", true), "model: Android SDK built for …")
        flag(Build.MANUFACTURER.contains("Genymotion", true), "manufacturer: Genymotion")
        flag(Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"), "generic brand + device")
        flag(Build.PRODUCT.equals("google_sdk", true), "product: google_sdk")
        flag(Build.PRODUCT.contains("sdk_gphone", true), "product: sdk_gphone*")
        flag(Build.HARDWARE.contains("goldfish") || Build.HARDWARE.contains("ranchu"),
            "hardware: ${Build.HARDWARE}")
        flag(Build.HARDWARE.contains("vbox86") || Build.HARDWARE.contains("windows"),
            "hardware: ${Build.HARDWARE}")
        flag(Sys.prop("ro.kernel.qemu") == "1", "ro.kernel.qemu=1")
        flag(Sys.prop("ro.boot.qemu") == "1", "ro.boot.qemu=1")
        flag(Sys.prop("ro.hardware.virtual_device") != null, "ro.hardware.virtual_device set")
        flag(File("/dev/socket/qemud").exists() || File("/dev/qemu_pipe").exists(), "qemu pipe device present")
        flag(File("/system/lib/libc_malloc_debug_qemu.so").exists(), "qemu malloc debug lib")

        val pm = context.packageManager
        listOf("com.google.android.launcher.layouts.genymotion", "com.bluestacks", "com.bignox.app")
            .forEach { pkg ->
                @Suppress("DEPRECATION")
                val installed = try { pm.getPackageInfo(pkg, 0); true } catch (_: PackageManager.NameNotFoundException) { false } catch (_: Throwable) { false }
                flag(installed, "emulator helper package: $pkg")
            }

        // Two or more independent signals is a confident call; one is reported but not decisive.
        return Result(signals.size >= 2, signals)
    }
}
