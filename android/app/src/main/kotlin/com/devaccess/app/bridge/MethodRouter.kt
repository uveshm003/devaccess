package com.devaccess.app.bridge

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.devaccess.app.BuildConfig
import com.devaccess.app.apps.AppsProvider
import com.devaccess.app.info.CameraInfo
import com.devaccess.app.info.InfoRegistry
import com.devaccess.app.info.MemoryStorageInfo
import com.devaccess.app.info.NetInfo
import com.devaccess.app.info.SensorInfo
import com.devaccess.app.intents.IntentLauncher
import com.devaccess.app.monitor.MonitorEngine
import com.devaccess.app.monitor.MonitorService
import com.devaccess.app.monitor.OverlayService
import com.devaccess.app.net.NetTools
import com.devaccess.app.report.Exporter
import com.devaccess.app.security.EmulatorDetector
import com.devaccess.app.security.RootShell
import com.devaccess.app.settings.Capabilities
import com.devaccess.app.settings.SettingsGateway
import com.devaccess.app.surface.Shortcuts
import com.devaccess.app.surface.StatsWidgetProvider
import com.devaccess.app.util.Prefs
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * The one request/response door onto the native layer (T-ARCH-1).
 *
 * Every handler is wrapped so a platform failure comes back as a structured error the UI can
 * render as an "unavailable" state — never as an unhandled exception (NFR-RELIABILITY-1).
 * Slow calls (info sections, GPU probe, apps list, network tools) hop onto a background
 * executor so the platform thread is never blocked (NFR-PERF-1).
 */
class MethodRouter(
    private val context: Context,
    private val activityProvider: () -> Activity?,
) : MethodChannel.MethodCallHandler {

    private val io = Executors.newFixedThreadPool(3)
    private val main = android.os.Handler(android.os.Looper.getMainLooper())

    /** Set by MainActivity when a SAF save completes. */
    var pendingSaveResult: MethodChannel.Result? = null
    var pendingPermissionResult: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // --- cheap, synchronous ------------------------------------------------
            "app.info" -> reply(result) { appInfo() }
            "app.dynamicColor" -> reply(result) { dynamicColorSeed() }
            "tier.status" -> reply(result) {
                Capabilities.status(context, call.argument<Boolean>("probeRoot") ?: false)
            }
            "tier.resetRootProbe" -> reply(result) { RootShell.resetCache(); true }
            "tier.requestWriteSettings" -> reply(result) { requestWriteSettings() }
            "emulator.detect" -> reply(result) {
                val d = EmulatorDetector.detect(context)
                mapOf("isEmulator" to d.isEmulator, "signals" to d.signals)
            }

            // --- settings read / write (FR-TG) --------------------------------------
            "settings.read" -> reply(result) {
                SettingsGateway.read(context, call.argument("scope")!!, call.argument("key")!!)
            }
            "settings.readMany" -> replyAsync(result) {
                SettingsGateway.readAll(context, call.argument("items") ?: emptyList())
            }
            "settings.write" -> reply(result) { settingsWrite(call) }
            "settings.demoMode" -> replyAsync(result) {
                SettingsGateway.demoMode(
                    context,
                    call.argument<Boolean>("enabled") ?: false,
                    call.argument("preset"),
                )
            }
            "settings.setProp" -> replyAsync(result) {
                SettingsGateway.setProp(call.argument("key")!!, call.argument("value")!!)
            }

            // --- intents (FR-QA) ----------------------------------------------------
            "intent.launch" -> reply(result) { launchChain(call) }
            "intent.canLaunch" -> reply(result) {
                IntentLauncher.resolves(context, IntentLauncher.specFrom(call.arguments as Map<String, Any?>))
            }
            "intent.resolveMany" -> replyAsync(result) {
                (call.argument<List<Map<String, Any?>>>("specs") ?: emptyList()).map {
                    IntentLauncher.resolves(context, IntentLauncher.specFrom(it))
                }
            }
            "intent.appScreen" -> reply(result) {
                IntentLauncher.appScreen(
                    activityProvider() ?: context,
                    call.argument("package")!!,
                    call.argument("screen") ?: "details",
                )
            }
            "intent.custom" -> reply(result) {
                IntentLauncher.custom(
                    activityProvider() ?: context,
                    IntentLauncher.specFrom(call.arguments as Map<String, Any?>),
                    Capabilities.tier(context, false),
                )
            }

            // --- device information (FR-INFO) ---------------------------------------
            "info.index" -> reply(result) { InfoRegistry.index() }
            "info.section" -> replyAsync(result) { InfoRegistry.section(context, call.argument("id")!!) }
            "info.all" -> replyAsync(result) { InfoRegistry.all(context) }

            // --- sensors (FR-SEN) ----------------------------------------------------
            "sensors.list" -> replyAsync(result) { SensorInfo.sensors(context) }
            "cameras.list" -> replyAsync(result) { CameraInfo.cameras(context) }

            // --- network (FR-NET) ----------------------------------------------------
            "net.status" -> reply(result) { NetInfo.status(context) }
            "net.wifi" -> reply(result) { NetInfo.wifi(context) }
            "net.telephony" -> reply(result) { NetInfo.telephony(context) }
            "net.dns" -> replyAsync(result) { NetTools.dns(call.argument("host")!!) }
            "net.reach" -> replyAsync(result) {
                NetTools.reach(
                    call.argument("host")!!,
                    call.argument<Int>("port") ?: 443,
                    call.argument<Int>("timeoutMs") ?: 4000,
                )
            }
            "net.http" -> replyAsync(result) {
                NetTools.http(call.argument("url")!!, call.argument("method") ?: "GET")
            }

            // --- apps (FR-APP) -------------------------------------------------------
            "apps.list" -> replyAsync(result) {
                AppsProvider.list(context, call.argument<Boolean>("all") ?: false)
            }
            "apps.permissions" -> replyAsync(result) {
                AppsProvider.permissions(context, call.argument("package")!!)
            }
            "apps.icon" -> replyAsync(result) {
                AppsProvider.icon(context, call.argument("package")!!, call.argument<Int>("size") ?: 96)
            }

            // --- monitoring (FR-MON) -------------------------------------------------
            "monitor.snapshot" -> replyAsync(result) { MonitorEngine.sample(context) }
            "monitor.setInterval" -> reply(result) {
                MonitorEngine.setInterval((call.argument<Int>("intervalMs") ?: 1000).toLong()); true
            }
            "monitor.setPaused" -> reply(result) {
                MonitorEngine.setPaused(call.argument<Boolean>("paused") ?: false); true
            }
            "monitor.startService" -> reply(result) {
                MonitorService.start(context, (call.argument<Int>("intervalMs") ?: 1000).toLong()); true
            }
            "monitor.stopService" -> reply(result) { MonitorService.stop(context); true }
            "monitor.serviceRunning" -> reply(result) { MonitorService.running }

            // --- overlay (FR-MON-6) ---------------------------------------------------
            "overlay.status" -> reply(result) {
                mapOf(
                    "granted" to OverlayService.hasPermission(context),
                    "running" to OverlayService.running,
                )
            }
            "overlay.requestPermission" -> reply(result) { requestOverlayPermission() }
            "overlay.start" -> reply(result) {
                if (!OverlayService.hasPermission(context)) {
                    mapOf("ok" to false, "error" to "Draw-over-other-apps permission not granted")
                } else {
                    OverlayService.start(context)
                    mapOf("ok" to true)
                }
            }
            "overlay.stop" -> reply(result) { OverlayService.stop(context); mapOf("ok" to true) }

            // --- permissions (FR-PERM) -------------------------------------------------
            "perm.status" -> reply(result) { permissionStatus(call.argument("permissions") ?: emptyList()) }
            "perm.request" -> requestPermissions(call, result)
            "perm.openSpecial" -> reply(result) { openSpecialAccess(call.argument("which")!!) }

            // --- reporting (FR-REP) -----------------------------------------------------
            "share.text" -> reply(result) {
                Exporter.shareText(
                    activityProvider() ?: context,
                    call.argument("text")!!,
                    call.argument("subject"),
                    call.argument("chooserTitle") ?: "Share device report",
                )
            }
            "share.file" -> replyAsync(result) {
                Exporter.shareFile(
                    activityProvider() ?: context,
                    call.argument("name")!!,
                    call.argument("mime") ?: "text/plain",
                    payloadOf(call),
                    call.argument("subject"),
                    call.argument("chooserTitle") ?: "Share device report",
                )
            }
            "file.save" -> saveFile(call, result)
            "report.pdf" -> replyAsync(result) {
                Exporter.renderPdf(call.argument("title") ?: "DevAccess report", call.argument("body")!!)
            }

            // --- surfaces (FR-SURF) ------------------------------------------------------
            "surface.setShortcuts" -> reply(result) {
                Shortcuts.set(context, call.argument("items") ?: emptyList())
            }
            "surface.clearShortcuts" -> reply(result) { Shortcuts.clear(context) }
            "surface.refreshWidgets" -> reply(result) { StatsWidgetProvider.refreshAll(context); true }

            // --- preferences (FR-SET) -----------------------------------------------------
            "prefs.load" -> reply(result) { Prefs.load(context) }
            "prefs.save" -> reply(result) { Prefs.save(context, call.argument("json")!!) }
            "prefs.clear" -> reply(result) { Prefs.clear(context) }

            else -> result.notImplemented()
        }
    }

    // ---- helpers -------------------------------------------------------------

    private inline fun reply(result: MethodChannel.Result, block: () -> Any?) {
        try {
            result.success(block())
        } catch (t: Throwable) {
            result.error(t.javaClass.simpleName, t.message, null)
        }
    }

    private fun replyAsync(result: MethodChannel.Result, block: () -> Any?) {
        io.execute {
            val outcome = try {
                Result.success(block())
            } catch (t: Throwable) {
                Result.failure<Any?>(t)
            }
            main.post {
                outcome.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { result.error(it.javaClass.simpleName, it.message, null) },
                )
            }
        }
    }

    private fun payloadOf(call: MethodCall): ByteArray =
        call.argument<ByteArray>("bytes")
            ?: (call.argument<String>("text") ?: "").toByteArray()

    private fun appInfo(): Map<String, Any?> {
        val pi = context.packageManager.getPackageInfo(context.packageName, 0)
        return mapOf(
            "packageName" to context.packageName,
            "versionName" to pi.versionName,
            "versionCode" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                pi.longVersionCode
            } else {
                @Suppress("DEPRECATION") pi.versionCode.toLong()
            },
            "flavor" to BuildConfig.DISTRIBUTION,
            "fullAccess" to BuildConfig.FULL_ACCESS,
            "debug" to BuildConfig.DEBUG,
            "sdkInt" to Build.VERSION.SDK_INT,
            "release" to Build.VERSION.RELEASE,
            "model" to "${Build.MANUFACTURER} ${Build.MODEL}",
        )
    }

    /**
     * FR-SET-1 — Material You. The wallpaper-derived palette lives in framework resources
     * from Android 12 (API 31); Dart seeds its ColorScheme from accent1-500. Returns null on
     * older releases so the app falls back to the user's chosen accent.
     */
    private fun dynamicColorSeed(): Int? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
        return try {
            context.resources.getColor(android.R.color.system_accent1_500, context.theme)
        } catch (t: Throwable) {
            null
        }
    }

    private fun settingsWrite(call: MethodCall): Map<String, Any?> {
        val scope: String = call.argument("scope")!!
        val required = SettingsGateway.requiredTier(scope)
        val tier = Capabilities.tier(context, probeRoot = false)
        // T3 subsumes T1/T2, so a simple ordering test is enough.
        if (tier < required) {
            return mapOf(
                "ok" to false,
                "error" to "Tier T$required required for Settings.$scope writes; current tier is T$tier",
                "requiredTier" to required,
                "currentTier" to tier,
            )
        }
        return SettingsGateway.write(
            context,
            scope,
            call.argument("key")!!,
            call.argument<Any>("value").toString(),
            call.argument("type") ?: SettingsGateway.TYPE_STRING,
            allowRoot = call.argument<Boolean>("allowRoot") ?: true,
        ) + mapOf("requiredTier" to required, "currentTier" to tier)
    }

    @Suppress("UNCHECKED_CAST")
    private fun launchChain(call: MethodCall): Map<String, Any?> {
        val chain = (call.argument<List<Map<String, Any?>>>("chain") ?: emptyList())
            .map { IntentLauncher.specFrom(it) }
        return IntentLauncher.launch(activityProvider() ?: context, chain)
    }

    private fun requestWriteSettings(): Map<String, Any?> {
        if (Capabilities.canWriteSystem(context)) return mapOf("ok" to true, "alreadyGranted" to true)
        return IntentLauncher.launch(
            activityProvider() ?: context,
            listOf(
                IntentLauncher.Spec(
                    Settings.ACTION_MANAGE_WRITE_SETTINGS,
                    "package:${context.packageName}", null, null, null, null, null,
                ),
                IntentLauncher.Spec(Settings.ACTION_MANAGE_WRITE_SETTINGS, null, null, null, null, null, null),
            ),
        )
    }

    private fun requestOverlayPermission(): Map<String, Any?> {
        if (OverlayService.hasPermission(context)) return mapOf("ok" to true, "alreadyGranted" to true)
        return IntentLauncher.launch(
            activityProvider() ?: context,
            listOf(
                IntentLauncher.Spec(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    "package:${context.packageName}", null, null, null, null, null,
                ),
                IntentLauncher.Spec(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, null, null, null, null, null, null),
            ),
        )
    }

    private fun permissionStatus(permissions: List<String>): Map<String, Any?> =
        permissions.associateWith { p ->
            try {
                context.checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED
            } catch (t: Throwable) {
                false
            }
        }

    private fun requestPermissions(call: MethodCall, result: MethodChannel.Result) {
        val permissions = call.argument<List<String>>("permissions") ?: emptyList()
        val activity = activityProvider()
        if (activity == null) {
            result.success(mapOf("ok" to false, "error" to "No foreground activity"))
            return
        }
        val missing = permissions.filter {
            activity.checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            result.success(permissionStatus(permissions) + mapOf("ok" to true))
            return
        }
        // POST_NOTIFICATIONS only exists from API 33; asking earlier throws.
        val requestable = missing.filter {
            it != Manifest.permission.POST_NOTIFICATIONS ||
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
        }
        if (requestable.isEmpty()) {
            result.success(permissionStatus(permissions) + mapOf("ok" to true))
            return
        }
        pendingPermissionResult?.success(mapOf("ok" to false, "error" to "superseded"))
        pendingPermissionResult = result
        try {
            activity.requestPermissions(requestable.toTypedArray(), PERMISSION_REQUEST_CODE)
        } catch (t: Throwable) {
            pendingPermissionResult = null
            result.success(mapOf("ok" to false, "error" to "${t.javaClass.simpleName}: ${t.message}"))
        }
    }

    fun onPermissionResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (requestCode != PERMISSION_REQUEST_CODE) return
        val pending = pendingPermissionResult ?: return
        pendingPermissionResult = null
        val map = permissions.mapIndexed { i, p ->
            p to (grantResults.getOrNull(i) == PackageManager.PERMISSION_GRANTED)
        }.toMap()
        pending.success(map + mapOf("ok" to true))
    }

    /** Special-access screens that cannot be granted by a runtime dialog. */
    private fun openSpecialAccess(which: String): Map<String, Any?> {
        val pkgUri = "package:${context.packageName}"
        val chain: List<IntentLauncher.Spec> = when (which) {
            "overlay" -> listOf(
                IntentLauncher.Spec(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, pkgUri, null, null, null, null, null),
                IntentLauncher.Spec(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, null, null, null, null, null, null),
            )
            "writeSettings" -> listOf(
                IntentLauncher.Spec(Settings.ACTION_MANAGE_WRITE_SETTINGS, pkgUri, null, null, null, null, null),
                IntentLauncher.Spec(Settings.ACTION_MANAGE_WRITE_SETTINGS, null, null, null, null, null, null),
            )
            "usageAccess" -> listOf(
                IntentLauncher.Spec(Settings.ACTION_USAGE_ACCESS_SETTINGS, null, null, null, null, null, null),
            )
            "batteryOptimisation" -> listOf(
                IntentLauncher.Spec(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS, null, null, null, null, null, null),
                IntentLauncher.Spec(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkgUri, null, null, null, null, null),
            )
            "requestBatteryExemption" -> listOf(
                IntentLauncher.Spec(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, pkgUri, null, null, null, null, null,
                ),
                IntentLauncher.Spec(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS, null, null, null, null, null, null),
            )
            "notifications" -> listOf(
                IntentLauncher.Spec(
                    "android.settings.APP_NOTIFICATION_SETTINGS", null, null, null, null, null,
                    mapOf("android.provider.extra.APP_PACKAGE" to context.packageName),
                ),
                IntentLauncher.Spec(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkgUri, null, null, null, null, null),
            )
            "notificationListener" -> listOf(
                IntentLauncher.Spec(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS, null, null, null, null, null, null),
            )
            "appDetails" -> listOf(
                IntentLauncher.Spec(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkgUri, null, null, null, null, null),
            )
            else -> return mapOf("ok" to false, "error" to "Unknown special-access screen '$which'")
        }
        return IntentLauncher.launch(activityProvider() ?: context, chain)
    }

    private fun saveFile(call: MethodCall, result: MethodChannel.Result) {
        val activity = activityProvider()
        if (activity == null) {
            result.success(mapOf("ok" to false, "error" to "No foreground activity"))
            return
        }
        pendingSaveResult?.success(mapOf("ok" to false, "error" to "superseded"))
        pendingSaveResult = result
        val started = Exporter.beginSave(
            activity,
            call.argument("name") ?: "devaccess-report.txt",
            call.argument("mime") ?: "text/plain",
            payloadOf(call),
        )
        if (!started) {
            pendingSaveResult = null
            result.success(mapOf("ok" to false, "error" to "No file picker available on this device"))
        }
    }

    fun onSaveResult(resultCode: Int, data: Intent?) {
        val pending = pendingSaveResult ?: return
        pendingSaveResult = null
        pending.success(Exporter.finishSave(context, resultCode, data))
    }

    fun dispose() {
        io.shutdownNow()
    }

    companion object {
        const val PERMISSION_REQUEST_CODE = 7401
    }
}
