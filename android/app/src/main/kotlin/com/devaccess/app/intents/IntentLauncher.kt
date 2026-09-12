package com.devaccess.app.intents

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import com.devaccess.app.BuildConfig

/**
 * FR-QA-1..4 — the deep-link backbone (C2).
 *
 * NFR-COMPAT-1 — every launcher carries a fallback chain. Samsung, Xiaomi and friends
 * rename or remove Settings activities, so the launcher walks the chain until an intent
 * resolves and reports which one actually fired. It never throws.
 */
object IntentLauncher {

    data class Spec(
        val action: String?,
        val data: String?,
        val packageName: String?,
        val component: String?,
        val category: String?,
        val mimeType: String?,
        val extras: Map<String, Any?>?,
    )

    @Suppress("UNCHECKED_CAST")
    fun specFrom(map: Map<String, Any?>): Spec = Spec(
        action = map["action"] as? String,
        data = map["data"] as? String,
        packageName = map["package"] as? String,
        component = map["component"] as? String,
        category = map["category"] as? String,
        mimeType = map["mime"] as? String,
        extras = map["extras"] as? Map<String, Any?>,
    )

    fun build(spec: Spec): Intent {
        val intent = Intent()
        spec.action?.let { intent.action = it }
        spec.category?.let { intent.addCategory(it) }
        when {
            spec.data != null && spec.mimeType != null ->
                intent.setDataAndType(Uri.parse(spec.data), spec.mimeType)
            spec.data != null -> intent.data = Uri.parse(spec.data)
            spec.mimeType != null -> intent.type = spec.mimeType
        }
        spec.component?.let { c ->
            val parts = c.split("/")
            if (parts.size == 2) {
                val cls = if (parts[1].startsWith(".")) parts[0] + parts[1] else parts[1]
                intent.component = ComponentName(parts[0], cls)
            }
        }
        spec.packageName?.let { if (spec.component == null) intent.setPackage(it) }
        spec.extras?.forEach { (k, v) ->
            when (v) {
                is String -> intent.putExtra(k, v)
                is Int -> intent.putExtra(k, v)
                is Long -> intent.putExtra(k, v)
                is Boolean -> intent.putExtra(k, v)
                is Double -> intent.putExtra(k, v)
                is Float -> intent.putExtra(k, v)
                is ArrayList<*> -> intent.putExtra(k, v.filterIsInstance<String>().toTypedArray())
                null -> Unit
                else -> intent.putExtra(k, v.toString())
            }
        }
        return intent
    }

    fun resolves(context: Context, spec: Spec): Boolean = try {
        val intent = build(spec)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.resolveActivity(
                intent, android.content.pm.PackageManager.ResolveInfoFlags.of(0),
            ) != null
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.resolveActivity(intent, 0) != null
        }
    } catch (t: Throwable) {
        false
    }

    /**
     * Fires the first intent in [chain] that resolves. Returns which index was used, or an
     * error describing why none of them worked.
     */
    fun launch(context: Context, chain: List<Spec>): Map<String, Any?> {
        if (chain.isEmpty()) return mapOf("ok" to false, "error" to "Empty intent chain")
        val attempted = mutableListOf<String>()
        chain.forEachIndexed { index, spec ->
            attempted += spec.action ?: spec.component ?: spec.data ?: "(empty)"
            val intent = build(spec)
            if (context !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                if (!resolves(context, spec)) return@forEachIndexed
                context.startActivity(intent)
                return mapOf(
                    "ok" to true,
                    "index" to index,
                    "used" to (spec.action ?: spec.component ?: spec.data),
                    "fallbackUsed" to (index > 0),
                )
            } catch (t: ActivityNotFoundException) {
                // Try the next link in the chain.
            } catch (t: SecurityException) {
                return mapOf("ok" to false, "error" to "Blocked by the OS: ${t.message}", "attempted" to attempted)
            } catch (t: Throwable) {
                return mapOf("ok" to false, "error" to "${t.javaClass.simpleName}: ${t.message}", "attempted" to attempted)
            }
        }
        return mapOf(
            "ok" to false,
            "error" to "No activity on this device handles any of these intents",
            "attempted" to attempted,
        )
    }

    /** FR-QA-4 / FR-APP-2 — per-app Settings deep links. */
    fun appScreen(context: Context, packageName: String, screen: String): Map<String, Any?> {
        val uri = Uri.fromParts("package", packageName, null)
        val chain = when (screen) {
            "details" -> listOf(
                Spec(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, uri.toString(), null, null, null, null, null),
            )
            "notifications" -> listOf(
                Spec(
                    "android.settings.APP_NOTIFICATION_SETTINGS", null, null, null, null, null,
                    mapOf("android.provider.extra.APP_PACKAGE" to packageName),
                ),
                Spec(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, uri.toString(), null, null, null, null, null),
            )
            "permissions" -> listOf(
                // The permissions sub-screen has no public action; the app-details screen is
                // the guaranteed parent (NFR-COMPAT-1).
                Spec(null, null, null, "com.android.settings/.applications.appinfo.AppInfoDashboardFragment", null, null, null),
                Spec(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, uri.toString(), null, null, null, null, null),
            )
            "storage" -> listOf(
                Spec("android.settings.APPLICATION_DETAILS_SETTINGS", uri.toString(), null, null, null, null, null),
            )
            "uninstall" -> listOf(
                Spec(Intent.ACTION_DELETE, uri.toString(), null, null, null, null, null),
            )
            "launch" -> {
                val i = context.packageManager.getLaunchIntentForPackage(packageName)
                    ?: return mapOf("ok" to false, "error" to "$packageName has no launcher activity")
                return try {
                    if (context !is Activity) i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(i)
                    mapOf("ok" to true, "used" to "launch intent")
                } catch (t: Throwable) {
                    mapOf("ok" to false, "error" to "${t.javaClass.simpleName}: ${t.message}")
                }
            }
            else -> listOf(
                Spec(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, uri.toString(), null, null, null, null, null),
            )
        }
        return launch(context, chain)
    }

    /**
     * FR-QA-7 — the free-form intent tester.
     *
     * Guarded: off-Play builds only. Play builds get a clear refusal rather than a silent
     * no-op, so the UI can explain why the control is locked (FR-TIER-3).
     */
    fun custom(context: Context, spec: Spec, tier: Int): Map<String, Any?> {
        if (!BuildConfig.FULL_ACCESS && tier < 2) {
            return mapOf(
                "ok" to false,
                "error" to "The intent tester is limited to the off-Play flavor or tier T2+ " +
                    "(FR-QA-7). Grant WRITE_SECURE_SETTINGS over adb to unlock it here.",
            )
        }
        return launch(context, listOf(spec))
    }
}
