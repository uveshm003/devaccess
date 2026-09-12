package com.devaccess.app.settings

import android.content.ContentResolver
import android.content.Context
import android.provider.Settings
import com.devaccess.app.bridge.Field
import com.devaccess.app.security.RootShell

/**
 * FR-TG-* — the single read/write door onto Settings.System / .Secure / .Global.
 *
 * Reads work at every tier (C2). Writes pick the cheapest route that the current tier
 * allows, then **re-read the key and return the real post-write value** (FR-TG-8) so the
 * UI never has to assume a write landed.
 */
object SettingsGateway {

    const val SCOPE_SYSTEM = "system"
    const val SCOPE_SECURE = "secure"
    const val SCOPE_GLOBAL = "global"

    const val TYPE_INT = "int"
    const val TYPE_LONG = "long"
    const val TYPE_FLOAT = "float"
    const val TYPE_STRING = "string"

    private fun cr(context: Context): ContentResolver = context.contentResolver

    /** Raw string read; null when the key is unset on this build. */
    fun readRaw(context: Context, scope: String, key: String): String? = try {
        when (scope) {
            SCOPE_SYSTEM -> Settings.System.getString(cr(context), key)
            SCOPE_SECURE -> Settings.Secure.getString(cr(context), key)
            else -> Settings.Global.getString(cr(context), key)
        }
    } catch (t: Throwable) {
        null
    }

    /** Wrapped read for the info dashboard and the toggle list. */
    fun read(context: Context, scope: String, key: String): Map<String, Any?> {
        val raw = readRaw(context, scope, key)
        return if (raw == null) {
            Field.unavailable("Key '$key' is not set in Settings.${scope.replaceFirstChar { it.uppercase() }} on this build")
        } else {
            Field.ok(raw)
        }
    }

    fun readAll(context: Context, items: List<Map<String, Any?>>): List<Map<String, Any?>> =
        items.map { item ->
            val scope = item["scope"] as? String ?: SCOPE_GLOBAL
            val key = item["key"] as? String ?: ""
            mapOf("scope" to scope, "key" to key) + read(context, scope, key)
        }

    /** Which tier is required to write [scope]. Section 5. */
    fun requiredTier(scope: String): Int =
        if (scope == SCOPE_SYSTEM) Capabilities.T1 else Capabilities.T2

    data class WriteOutcome(
        val ok: Boolean,
        val method: String,
        val actual: String?,
        val error: String?,
    ) {
        fun toMap(previous: String?) = mapOf(
            "ok" to ok,
            "method" to method,
            "actual" to actual,
            "previous" to previous,
            "error" to error,
        )
    }

    /**
     * Writes a value and verifies it. [previous] is echoed back so the caller can offer undo.
     * NFR-SEC-1 — the caller is responsible for having confirmed the action with the user.
     */
    fun write(
        context: Context,
        scope: String,
        key: String,
        value: String,
        type: String,
        allowRoot: Boolean,
    ): Map<String, Any?> {
        val previous = readRaw(context, scope, key)
        val direct = tryDirectWrite(context, scope, key, value, type)
        var outcome = direct
        if (!direct.ok && allowRoot && RootShell.hasRoot(true)) {
            outcome = tryRootWrite(scope, key, value)
        }

        // FR-TG-8 — never assume success; the truth is whatever the key reads back as.
        val actual = readRaw(context, scope, key)
        val verified = actual != null && valuesMatch(actual, value, type)
        return WriteOutcome(
            ok = verified,
            method = outcome.method,
            actual = actual,
            error = when {
                verified -> null
                outcome.error != null -> outcome.error
                else -> "Write reported success but '$key' still reads '$actual'"
            },
        ).toMap(previous)
    }

    private fun valuesMatch(actual: String, wanted: String, type: String): Boolean = when (type) {
        TYPE_FLOAT -> actual.toFloatOrNull()?.let { a ->
            wanted.toFloatOrNull()?.let { w -> kotlin.math.abs(a - w) < 0.0001f }
        } ?: false
        TYPE_INT, TYPE_LONG -> actual.trim().toLongOrNull() == wanted.trim().toLongOrNull()
        else -> actual == wanted
    }

    private fun tryDirectWrite(
        context: Context,
        scope: String,
        key: String,
        value: String,
        type: String,
    ): WriteOutcome {
        val requiredOk = when (scope) {
            SCOPE_SYSTEM -> Capabilities.canWriteSystem(context)
            else -> Capabilities.canWriteSecure(context)
        }
        if (!requiredOk) {
            return WriteOutcome(
                false, "none", null,
                if (scope == SCOPE_SYSTEM) {
                    "WRITE_SETTINGS not granted (tier T1 required)"
                } else {
                    "WRITE_SECURE_SETTINGS not granted (tier T2 required)"
                },
            )
        }
        return try {
            val resolver = cr(context)
            val done = when (scope) {
                SCOPE_SYSTEM -> putSystem(resolver, key, value, type)
                SCOPE_SECURE -> putSecure(resolver, key, value, type)
                else -> putGlobal(resolver, key, value, type)
            }
            WriteOutcome(done, "content-provider", null, if (done) null else "ContentResolver rejected the write")
        } catch (t: Throwable) {
            WriteOutcome(false, "content-provider", null, "${t.javaClass.simpleName}: ${t.message}")
        }
    }

    private fun putSystem(r: ContentResolver, key: String, v: String, type: String) = when (type) {
        TYPE_INT -> Settings.System.putInt(r, key, v.toInt())
        TYPE_LONG -> Settings.System.putLong(r, key, v.toLong())
        TYPE_FLOAT -> Settings.System.putFloat(r, key, v.toFloat())
        else -> Settings.System.putString(r, key, v)
    }

    private fun putSecure(r: ContentResolver, key: String, v: String, type: String) = when (type) {
        TYPE_INT -> Settings.Secure.putInt(r, key, v.toInt())
        TYPE_LONG -> Settings.Secure.putLong(r, key, v.toLong())
        TYPE_FLOAT -> Settings.Secure.putFloat(r, key, v.toFloat())
        else -> Settings.Secure.putString(r, key, v)
    }

    private fun putGlobal(r: ContentResolver, key: String, v: String, type: String) = when (type) {
        TYPE_INT -> Settings.Global.putInt(r, key, v.toInt())
        TYPE_LONG -> Settings.Global.putLong(r, key, v.toLong())
        TYPE_FLOAT -> Settings.Global.putFloat(r, key, v.toFloat())
        else -> Settings.Global.putString(r, key, v)
    }

    /** T3 — `settings put` through su, for keys the content provider still refuses. */
    private fun tryRootWrite(scope: String, key: String, value: String): WriteOutcome {
        val r = RootShell.exec("settings put $scope $key $value")
        return WriteOutcome(r.ok, "su settings put", null, if (r.ok) null else r.stderr.trim().ifEmpty { "su exited ${r.code}" })
    }

    /** T3 — `setprop`, used by the advanced properties panel. */
    fun setProp(key: String, value: String): Map<String, Any?> {
        if (!RootShell.hasRoot(true)) {
            return mapOf("ok" to false, "error" to "Root (T3) required for setprop")
        }
        val r = RootShell.exec("setprop $key $value")
        return mapOf("ok" to r.ok, "error" to if (r.ok) null else r.stderr.trim())
    }

    /**
     * FR-TG-5 — SystemUI demo mode. Needs the `sysui_demo_allowed` global flag plus a
     * broadcast; the broadcast requires DUMP, which only arrives over adb, so we fall back
     * to `su am broadcast` when root is available.
     */
    fun demoMode(context: Context, enable: Boolean, preset: Map<String, String>?): Map<String, Any?> {
        val errors = mutableListOf<String>()
        val allow = write(context, SCOPE_GLOBAL, "sysui_demo_allowed", "1", TYPE_INT, allowRoot = true)
        if (allow["ok"] != true) errors += "sysui_demo_allowed: ${allow["error"]}"

        val commands = mutableListOf<Map<String, String>>()
        if (enable) {
            commands += mapOf("command" to "enter")
            commands += (preset ?: defaultDemoPreset())
        } else {
            commands += mapOf("command" to "exit")
        }

        var sent = 0
        for (c in commands) {
            if (sendDemoBroadcast(context, c)) sent++ else errors += "broadcast ${c["command"]} rejected"
        }
        return mapOf(
            "ok" to (sent == commands.size && errors.isEmpty()),
            "sent" to sent,
            "error" to errors.joinToString("; ").ifEmpty { null },
        )
    }

    /** A clean status bar for screenshots: full signal, no notifications, fixed clock. */
    private fun defaultDemoPreset(): Map<String, String> = mapOf(
        "command" to "battery", "level" to "100", "plugged" to "false",
    )

    private fun sendDemoBroadcast(context: Context, extras: Map<String, String>): Boolean {
        val intent = android.content.Intent("com.android.systemui.demo")
        extras.forEach { (k, v) -> intent.putExtra(k, v) }
        return try {
            context.sendBroadcast(intent)
            true
        } catch (t: Throwable) {
            if (RootShell.hasRoot(false)) {
                val args = extras.entries.joinToString(" ") { "-e ${it.key} ${it.value}" }
                RootShell.exec("am broadcast -a com.android.systemui.demo $args").ok
            } else {
                false
            }
        }
    }
}
