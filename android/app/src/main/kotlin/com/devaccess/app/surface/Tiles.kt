package com.devaccess.app.surface

import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi
import com.devaccess.app.MainActivity
import com.devaccess.app.settings.Capabilities
import com.devaccess.app.settings.SettingsGateway

/**
 * FR-SURF-1 / C8 — Quick Settings tiles must be native; there is no Dart equivalent.
 * T-ARCH-5 — each tile re-reads live state in onStartListening so it never shows a stale value.
 */

/** Base helper: starting an activity from a tile has to go through the collapse path. */
abstract class BaseTileService : TileService() {

    protected fun launch(intent: Intent) {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(
                android.app.PendingIntent.getActivity(
                    this, 0, intent,
                    android.app.PendingIntent.FLAG_IMMUTABLE or
                        android.app.PendingIntent.FLAG_UPDATE_CURRENT,
                ),
            )
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }

    protected fun setTile(state: Int, subtitle: String?) {
        qsTile?.let { t ->
            t.state = state
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && subtitle != null) {
                t.subtitle = subtitle
            }
            t.updateTile()
        }
    }
}

/** Opens Developer Options, falling back to the main Settings screen (FR-QA-2). */
class DevOptionsTileService : BaseTileService() {
    override fun onStartListening() {
        val enabled = try {
            Settings.Global.getInt(contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0) == 1
        } catch (t: Throwable) {
            false
        }
        setTile(
            if (enabled) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE,
            if (enabled) "Enabled" else "Not enabled",
        )
    }

    override fun onClick() {
        val primary = Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
        val fallback = Intent(Settings.ACTION_SETTINGS)
        launch(if (primary.resolveActivity(packageManager) != null) primary else fallback)
    }
}

/**
 * FR-SURF-1 + FR-TG-1 — one-tap "kill all animations" / restore.
 * Requires T2; without it the tile stays unavailable and explains itself in the subtitle
 * rather than silently doing nothing (FR-TIER-3).
 */
class AnimationsTileService : BaseTileService() {

    private val keys = listOf(
        Settings.Global.WINDOW_ANIMATION_SCALE,
        Settings.Global.TRANSITION_ANIMATION_SCALE,
        Settings.Global.ANIMATOR_DURATION_SCALE,
    )

    private fun animationsOff(): Boolean = keys.all {
        (Settings.Global.getFloat(contentResolver, it, 1f)) == 0f
    }

    override fun onStartListening() {
        if (!Capabilities.canWriteSecure(this)) {
            setTile(Tile.STATE_UNAVAILABLE, "Needs T2 (adb grant)")
            return
        }
        val off = try { animationsOff() } catch (t: Throwable) { false }
        setTile(if (off) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE, if (off) "Off" else "On")
    }

    override fun onClick() {
        if (!Capabilities.canWriteSecure(this)) {
            launch(
                Intent(this, MainActivity::class.java)
                    .putExtra(MainActivity.EXTRA_ROUTE, "tier"),
            )
            return
        }
        val target = if (animationsOff()) "1.0" else "0.0"
        keys.forEach {
            SettingsGateway.write(
                this, SettingsGateway.SCOPE_GLOBAL, it, target,
                SettingsGateway.TYPE_FLOAT, allowRoot = false,
            )
        }
        onStartListening()
    }
}

/** Opens Wi-Fi settings (FR-NET-5). */
class WifiTileService : BaseTileService() {
    override fun onStartListening() = setTile(Tile.STATE_INACTIVE, null)

    override fun onClick() {
        val panel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            Intent(Settings.Panel.ACTION_WIFI)
        } else {
            Intent(Settings.ACTION_WIFI_SETTINGS)
        }
        launch(
            if (panel.resolveActivity(packageManager) != null) {
                panel
            } else {
                Intent(Settings.ACTION_WIRELESS_SETTINGS)
            },
        )
    }
}

/** Opens the DevAccess dashboard. */
class DashboardTileService : BaseTileService() {
    override fun onStartListening() = setTile(Tile.STATE_INACTIVE, null)

    override fun onClick() {
        launch(Intent(this, MainActivity::class.java).putExtra(MainActivity.EXTRA_ROUTE, "home"))
    }
}
