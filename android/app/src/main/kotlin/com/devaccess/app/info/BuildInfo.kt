package com.devaccess.app.info

import android.app.ActivityManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import com.devaccess.app.bridge.Field
import com.devaccess.app.security.EmulatorDetector
import com.devaccess.app.security.RootShell
import com.devaccess.app.settings.Capabilities
import com.devaccess.app.util.Sys
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** Appendix B — Device & Build, OS & Security and System state sections. */
object BuildInfo {

    fun deviceAndBuild(context: Context): List<Map<String, Any?>> = listOf(
        field("manufacturer", "Manufacturer", Field.of { Build.MANUFACTURER }),
        field("brand", "Brand", Field.of { Build.BRAND }),
        field("model", "Model", Field.of { Build.MODEL }),
        field("product", "Product", Field.of { Build.PRODUCT }),
        field("device", "Device", Field.of { Build.DEVICE }),
        field("board", "Board", Field.of { Build.BOARD }),
        field("hardware", "Hardware", Field.of { Build.HARDWARE }),
        field("bootloader", "Bootloader", Field.of { Build.BOOTLOADER }),
        field("fingerprint", "Fingerprint", Field.of { Build.FINGERPRINT }, sensitive = true),
        field("buildId", "Build ID", Field.of { Build.ID }),
        field("buildTags", "Build tags", Field.of { Build.TAGS }),
        field("buildType", "Build type", Field.of { Build.TYPE }),
        field("incremental", "Incremental", Field.of { Build.VERSION.INCREMENTAL }),
        field("buildTime", "Build time", Field.of { formatTime(Build.TIME) }),
        field("host", "Build host", Field.of { Build.HOST }),
        field("user", "Build user", Field.of { Build.USER }),
        field("radio", "Radio version", radioVersion()),
        field("socManufacturer", "SoC manufacturer", socManufacturer()),
        field("socModel", "SoC model", socModel()),
        field("serial", "Serial number", serial(), sensitive = true),
        field("imei", "IMEI / MEID", imei(), sensitive = true),
        field("debuggable", "App is debuggable", Field.of {
            (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        }),
        field("emulator", "Running on emulator", Field.of {
            EmulatorDetector.detect(context).isEmulator
        }),
        field("emulatorSignals", "Emulator signals", Field.of {
            EmulatorDetector.detect(context).signals.ifEmpty { listOf("none") }.joinToString(", ")
        }),
    )

    fun osAndSecurity(context: Context): List<Map<String, Any?>> {
        val root = RootShell.cachedRoot()
        return listOf(
            field("release", "Android release", Field.of { Build.VERSION.RELEASE }),
            field("codename", "Codename", Field.of {
                Build.VERSION.CODENAME.takeIf { it != "REL" } ?: "REL (released)"
            }),
            field("sdkInt", "API level", Field.of { Build.VERSION.SDK_INT }),
            field("securityPatch", "Security patch", Field.of { Build.VERSION.SECURITY_PATCH }),
            field("kernel", "Kernel version", Field.of { System.getProperty("os.version") }),
            field("kernelFull", "Kernel (full)", Field.of { Sys.readFile("/proc/version") }),
            field("arch", "Kernel architecture", Field.of { System.getProperty("os.arch") }),
            field("selinux", "SELinux mode", selinuxMode()),
            field("verifiedBoot", "Verified boot state", propField("ro.boot.verifiedbootstate", "Not exposed by this bootloader")),
            field("bootloaderLocked", "Bootloader lock state", bootloaderLock()),
            field("vbmeta", "vbmeta device state", propField("ro.boot.vbmeta.device_state", "Not exposed by this bootloader")),
            field("encryption", "Encryption state", encryptionState()),
            field("rootStatus", "Root status", Field.ok(
                when (root) {
                    true -> "Root granted (su returns uid 0)"
                    false -> "No root"
                    null -> "Not probed — tap to probe"
                },
            )),
            field("suBinary", "su binary", RootShell.suBinary()?.let { Field.ok(it) }
                ?: Field.ok("not found")),
            field("magisk", "Magisk artifacts", Field.ok(
                RootShell.magiskArtifacts().ifEmpty { listOf("none") }.joinToString(", "),
            )),
            field("integrity", "Play Integrity verdict", Field.unavailable(
                "Requires the Play Integrity API with a Google Cloud project and a server-side " +
                    "verdict check; DevAccess is offline-first and ships no backend (NFR-PRIV-1). " +
                    "Verified-boot state and root detection above are the on-device substitute.",
            )),
            field("playServices", "Play services version", playServicesVersion(context)),
            field("uptime", "Uptime", Field.of { formatDuration(SystemClock.elapsedRealtime()) }),
            field("bootTime", "Boot time", Field.of {
                formatTime(System.currentTimeMillis() - SystemClock.elapsedRealtime())
            }),
            field("devOptions", "Developer options enabled", devOptionsEnabled(context)),
            field("adbEnabled", "USB debugging enabled", adbEnabled(context)),
            field("tier", "DevAccess access tier", Field.ok("T${Capabilities.tier(context, false)}")),
            field("abis", "Supported ABIs", Field.of { Build.SUPPORTED_ABIS.joinToString(", ") }),
        )
    }

    fun systemState(context: Context): List<Map<String, Any?>> = listOf(
        field("locale", "Locale", Field.of { Locale.getDefault().toLanguageTag() }),
        field("localeDisplay", "Locale (display)", Field.of { Locale.getDefault().displayName }),
        field("region", "Region", Field.of { Locale.getDefault().country.ifEmpty { null } }),
        field("timezone", "Time zone", Field.of { TimeZone.getDefault().id }),
        field("timezoneOffset", "UTC offset", Field.of {
            val min = TimeZone.getDefault().getOffset(System.currentTimeMillis()) / 60000
            String.format(Locale.US, "%+03d:%02d", min / 60, kotlin.math.abs(min % 60))
        }),
        field("time24h", "24-hour clock", Field.of {
            Settings.System.getString(context.contentResolver, Settings.System.TIME_12_24) == "24"
        }),
        field("screenTimeout", "Screen timeout", Field.of {
            val ms = Settings.System.getInt(context.contentResolver, Settings.System.SCREEN_OFF_TIMEOUT, -1)
            if (ms < 0) null else "${ms / 1000}s"
        }),
        field("autoRotate", "Auto-rotate", Field.of {
            Settings.System.getInt(context.contentResolver, Settings.System.ACCELEROMETER_ROTATION, 0) == 1
        }),
        field("dnd", "Do Not Disturb", dndState(context)),
        field("batteryOptimised", "Ignoring battery optimisations", batteryOptimisation(context)),
        field("lowRamDevice", "Low-RAM device", Field.of {
            (context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).isLowRamDevice
        }),
        field("defaultInput", "Default input method", Field.of {
            Settings.Secure.getString(context.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
        }),
        field("fontScale", "Font scale", Field.of { context.resources.configuration.fontScale }),
        field("uiMode", "Night mode", Field.of {
            val mode = context.resources.configuration.uiMode and
                android.content.res.Configuration.UI_MODE_NIGHT_MASK
            if (mode == android.content.res.Configuration.UI_MODE_NIGHT_YES) "dark" else "light"
        }),
    )

    // ---- individual reads -------------------------------------------------

    private fun radioVersion(): Map<String, Any?> = Field.of("Radio version not exposed") {
        Build.getRadioVersion()?.takeIf { it.isNotBlank() }
    }

    private fun socManufacturer(): Map<String, Any?> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            Field.of { Build.SOC_MANUFACTURER.takeIf { it != Build.UNKNOWN } }
        } else {
            propField("ro.soc.manufacturer", "Build.SOC_MANUFACTURER needs API 31+")
        }

    private fun socModel(): Map<String, Any?> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            Field.of { Build.SOC_MODEL.takeIf { it != Build.UNKNOWN } }
        } else {
            propField("ro.soc.model", "Build.SOC_MODEL needs API 31+")
        }

    /** C4 — hardware serial is off-limits from API 29. */
    private fun serial(): Map<String, Any?> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            Field.restricted("Serial numbers are restricted to privileged apps from Android 10 (API 29)")
        } else {
            @Suppress("DEPRECATION")
            Field.of { Build.SERIAL.takeIf { it != Build.UNKNOWN } }
        }

    /** C4 — IMEI needs READ_PRIVILEGED_PHONE_STATE from API 29; never obtainable here. */
    private fun imei(): Map<String, Any?> = Field.restricted(
        "IMEI/MEID requires READ_PRIVILEGED_PHONE_STATE (system apps only) from Android 10 (API 29)",
    )

    private fun propField(key: String, whenMissing: String): Map<String, Any?> =
        Sys.prop(key)?.let { Field.ok(it) } ?: Field.restricted(whenMissing)

    private fun bootloaderLock(): Map<String, Any?> {
        val locked = Sys.prop("ro.boot.flash.locked")
        val vb = Sys.prop("ro.boot.verifiedbootstate")
        return when {
            locked == "1" -> Field.ok("locked")
            locked == "0" -> Field.ok("unlocked")
            vb.equals("green", true) -> Field.ok("locked (inferred from verified boot: green)")
            vb != null -> Field.ok("unlocked (inferred from verified boot: $vb)")
            else -> Field.restricted("ro.boot.flash.locked is not readable on this build")
        }
    }

    private fun selinuxMode(): Map<String, Any?> {
        Sys.readFile("/sys/fs/selinux/enforce")?.let {
            return Field.ok(if (it.trim() == "1") "Enforcing" else "Permissive")
        }
        val r = Sys.exec(listOf("getenforce"), 1500)
        return if (r.ok && r.stdout.isNotBlank()) {
            Field.ok(r.stdout.trim())
        } else {
            Field.restricted("/sys/fs/selinux/enforce is not readable by unprivileged apps on this build")
        }
    }

    private fun encryptionState(): Map<String, Any?> {
        val state = Sys.prop("ro.crypto.state")
        val type = Sys.prop("ro.crypto.type")
        return when {
            state == null && type == null ->
                Field.restricted("ro.crypto.* is not readable on this build")
            else -> Field.ok(
                buildString {
                    append(state ?: "unknown")
                    if (type != null) append(" (").append(type).append(")")
                },
            )
        }
    }

    private fun playServicesVersion(context: Context): Map<String, Any?> = try {
        val pi = context.packageManager.getPackageInfo("com.google.android.gms", 0)
        Field.ok(pi.versionName ?: "installed")
    } catch (t: PackageManager.NameNotFoundException) {
        Field.unavailable("Google Play services is not installed on this device")
    } catch (t: Throwable) {
        Field.unavailable("Package not visible to this app")
    }

    fun devOptionsEnabled(context: Context): Map<String, Any?> = Field.of {
        Settings.Global.getInt(
            context.contentResolver,
            Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
            0,
        ) == 1
    }

    fun adbEnabled(context: Context): Map<String, Any?> = Field.of {
        Settings.Global.getInt(context.contentResolver, Settings.Global.ADB_ENABLED, 0) == 1
    }

    private fun dndState(context: Context): Map<String, Any?> = Field.of {
        when (Settings.Global.getInt(context.contentResolver, "zen_mode", 0)) {
            0 -> "Off"
            1 -> "Priority only"
            2 -> "Total silence"
            3 -> "Alarms only"
            else -> "Unknown"
        }
    }

    private fun batteryOptimisation(context: Context): Map<String, Any?> = Field.of {
        val pm = context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
        pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun formatTime(ms: Long): String =
        SimpleDateFormat("yyyy-MM-dd HH:mm:ss z", Locale.US).format(Date(ms))

    fun formatDuration(ms: Long): String {
        val s = ms / 1000
        return "%dd %02dh %02dm %02ds".format(s / 86400, (s % 86400) / 3600, (s % 3600) / 60, s % 60)
    }

    fun field(
        key: String,
        label: String,
        value: Map<String, Any?>,
        sensitive: Boolean = false,
    ): Map<String, Any?> = value + mapOf("k" to key, "l" to label, "sensitive" to sensitive)
}
