package com.devaccess.app.surface

import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build
import com.devaccess.app.MainActivity
import com.devaccess.app.R

/**
 * FR-SURF-3 — dynamic launcher shortcuts, published from the user's favourites.
 * C8: ShortcutManager has no Dart equivalent, so Dart hands us the list and we publish it.
 */
object Shortcuts {

    private const val MAX = 4

    fun set(context: Context, items: List<Map<String, Any?>>): Map<String, Any?> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) {
            return mapOf("ok" to false, "error" to "Dynamic shortcuts need Android 7.1 (API 25)")
        }
        val sm = context.getSystemService(ShortcutManager::class.java)
            ?: return mapOf("ok" to false, "error" to "ShortcutManager unavailable")
        return try {
            val limit = minOf(MAX, sm.maxShortcutCountPerActivity)
            val shortcuts = items.take(limit).mapNotNull { item ->
                val id = item["id"] as? String ?: return@mapNotNull null
                val label = item["label"] as? String ?: id
                val route = item["route"] as? String ?: "home"
                val target = item["target"] as? String
                ShortcutInfo.Builder(context, id)
                    .setShortLabel(label.take(10))
                    .setLongLabel(label.take(25))
                    .setIcon(Icon.createWithResource(context, R.drawable.ic_tile_dash))
                    .setIntent(
                        Intent(context, MainActivity::class.java)
                            .setAction(Intent.ACTION_MAIN)
                            .putExtra(MainActivity.EXTRA_ROUTE, route)
                            .putExtra(MainActivity.EXTRA_TARGET, target),
                    )
                    .build()
            }
            sm.dynamicShortcuts = shortcuts
            mapOf("ok" to true, "published" to shortcuts.size, "limit" to limit)
        } catch (t: Throwable) {
            mapOf("ok" to false, "error" to "${t.javaClass.simpleName}: ${t.message}")
        }
    }

    fun clear(context: Context): Map<String, Any?> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return mapOf("ok" to true)
        return try {
            context.getSystemService(ShortcutManager::class.java)?.removeAllDynamicShortcuts()
            mapOf("ok" to true)
        } catch (t: Throwable) {
            mapOf("ok" to false, "error" to t.message)
        }
    }
}
