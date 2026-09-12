package com.devaccess.app.info

import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.provider.Settings
import android.util.DisplayMetrics
import android.view.Display
import android.view.WindowManager
import com.devaccess.app.bridge.Field
import com.devaccess.app.info.BuildInfo.field
import kotlin.math.sqrt

/** Appendix B — Display section, including the live animation scales (FR-TG-1 read at T0). */
object DisplayInfo {

    fun fields(context: Context): List<Map<String, Any?>> {
        val dm = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val display: Display? = dm.getDisplay(Display.DEFAULT_DISPLAY)
        val metrics = realMetrics(context)

        return listOf(
            field("resolution", "Resolution", Field.of {
                metrics?.let { "${it.widthPixels} × ${it.heightPixels} px" }
            }),
            field("densityDpi", "Density", Field.of { metrics?.let { "${it.densityDpi} dpi" } }),
            field("densityBucket", "Density bucket", Field.of {
                metrics?.densityDpi?.let { bucket(it) }
            }),
            field("scaledDensity", "Logical size", Field.of {
                metrics?.let {
                    "${(it.widthPixels / it.density).toInt()} × ${(it.heightPixels / it.density).toInt()} dp"
                }
            }),
            field("physicalSize", "Physical size", Field.of {
                metrics?.let {
                    val w = it.widthPixels / it.xdpi
                    val h = it.heightPixels / it.ydpi
                    "%.2f in".format(sqrt((w * w + h * h).toDouble()))
                }
            }),
            field("refreshRate", "Refresh rate", Field.of {
                display?.refreshRate?.let { "%.1f Hz".format(it) }
            }),
            field("supportedModes", "Supported modes", supportedModes(display)),
            field("hdr", "HDR capabilities", hdr(display)),
            field("cutout", "Display cutout", cutout(context)),
            field("insets", "System bar insets", insets(context)),
            field("rotation", "Rotation", Field.of {
                when (display?.rotation) {
                    android.view.Surface.ROTATION_0 -> "0° (portrait)"
                    android.view.Surface.ROTATION_90 -> "90°"
                    android.view.Surface.ROTATION_180 -> "180°"
                    android.view.Surface.ROTATION_270 -> "270°"
                    else -> null
                }
            }),
            field("displayCount", "Attached displays", Field.of { dm.displays.size }),
            field("brightness", "Screen brightness", Field.of {
                Settings.System.getInt(context.contentResolver, Settings.System.SCREEN_BRIGHTNESS, -1)
                    .takeIf { it >= 0 }
                    ?.let { "$it / 255 (${(it * 100 / 255)}%)" }
            }),
            field("brightnessMode", "Adaptive brightness", Field.of {
                Settings.System.getInt(
                    context.contentResolver,
                    Settings.System.SCREEN_BRIGHTNESS_MODE,
                    0,
                ) == Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC
            }),
            field("windowAnim", "Window animation scale", animScale(context, Settings.Global.WINDOW_ANIMATION_SCALE)),
            field("transitionAnim", "Transition animation scale", animScale(context, Settings.Global.TRANSITION_ANIMATION_SCALE)),
            field("animatorDuration", "Animator duration scale", animScale(context, Settings.Global.ANIMATOR_DURATION_SCALE)),
        )
    }

    private fun realMetrics(context: Context): DisplayMetrics? = try {
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = wm.maximumWindowMetrics.bounds
            val base = context.resources.displayMetrics
            metrics.widthPixels = bounds.width()
            metrics.heightPixels = bounds.height()
            metrics.densityDpi = base.densityDpi
            metrics.density = base.density
            metrics.xdpi = base.xdpi
            metrics.ydpi = base.ydpi
        } else {
            @Suppress("DEPRECATION")
            wm.defaultDisplay.getRealMetrics(metrics)
        }
        metrics
    } catch (t: Throwable) {
        null
    }

    private fun bucket(dpi: Int): String = when {
        dpi <= 120 -> "ldpi"
        dpi <= 160 -> "mdpi"
        dpi <= 240 -> "hdpi"
        dpi <= 320 -> "xhdpi"
        dpi <= 480 -> "xxhdpi"
        dpi <= 640 -> "xxxhdpi"
        else -> "${dpi}dpi"
    }

    private fun supportedModes(display: Display?): Map<String, Any?> = Field.of {
        display?.supportedModes
            ?.joinToString(", ") { "${it.physicalWidth}×${it.physicalHeight}@%.0fHz".format(it.refreshRate) }
            ?.takeIf { it.isNotBlank() }
    }

    private fun hdr(display: Display?): Map<String, Any?> {
        if (display == null) return Field.unavailable("No default display")
        @Suppress("DEPRECATION")
        val caps = display.hdrCapabilities
            ?: return Field.unavailable("Display reports no HDR capabilities")
        val types = caps.supportedHdrTypes.map {
            when (it) {
                Display.HdrCapabilities.HDR_TYPE_DOLBY_VISION -> "Dolby Vision"
                Display.HdrCapabilities.HDR_TYPE_HDR10 -> "HDR10"
                Display.HdrCapabilities.HDR_TYPE_HDR10_PLUS -> "HDR10+"
                Display.HdrCapabilities.HDR_TYPE_HLG -> "HLG"
                else -> "type $it"
            }
        }
        return if (types.isEmpty()) Field.ok("none") else Field.ok(types.joinToString(", "))
    }

    private fun cutout(context: Context): Map<String, Any?> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            return Field.restricted("Display cutouts were introduced in Android 9 (API 28)")
        }
        return Field.of("No cutout reported") {
            val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val cut = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                wm.currentWindowMetrics.windowInsets.displayCutout
            } else {
                @Suppress("DEPRECATION")
                wm.defaultDisplay.cutout
            }
            cut?.let {
                "safe insets L${it.safeInsetLeft} T${it.safeInsetTop} R${it.safeInsetRight} B${it.safeInsetBottom}"
            }
        }
    }

    private fun insets(context: Context): Map<String, Any?> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return Field.restricted("WindowMetrics insets need Android 11 (API 30)")
        }
        return Field.of {
            val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val i = wm.currentWindowMetrics.windowInsets
                .getInsets(android.view.WindowInsets.Type.systemBars())
            "L${i.left} T${i.top} R${i.right} B${i.bottom}"
        }
    }

    private fun animScale(context: Context, key: String): Map<String, Any?> = Field.of {
        Settings.Global.getFloat(context.contentResolver, key, 1.0f).let { "%.2f×".format(it) }
    }
}
