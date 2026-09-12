package com.devaccess.app.util

import android.content.Context

/**
 * FR-SET-3 — a single JSON blob of app preferences, owned and parsed by Dart.
 *
 * Keeping the schema on the Dart side means backup/restore is just "hand me the blob",
 * and the native layer never has to know what a favourite or a theme accent is.
 */
object Prefs {

    private const val FILE = "devaccess_prefs"
    private const val KEY = "state_json"

    private fun sp(context: Context) =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun load(context: Context): String? = try {
        sp(context).getString(KEY, null)
    } catch (t: Throwable) {
        null
    }

    fun save(context: Context, json: String): Boolean = try {
        sp(context).edit().putString(KEY, json).commit()
    } catch (t: Throwable) {
        false
    }

    fun clear(context: Context): Boolean = try {
        sp(context).edit().clear().commit()
    } catch (t: Throwable) {
        false
    }
}
