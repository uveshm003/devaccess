package com.devaccess.app.apps

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.os.Build
import com.devaccess.app.BuildConfig
import java.io.ByteArrayOutputStream

/**
 * FR-APP-1..3 — the apps inspector.
 *
 * C6 — the Play flavor only enumerates packages with a launcher activity, which the
 * narrow `<queries>` block in the manifest already permits. The foss flavor holds
 * QUERY_ALL_PACKAGES and can list everything, but only after explicit user consent.
 */
object AppsProvider {

    fun canListAll(): Boolean = BuildConfig.FULL_ACCESS

    fun list(context: Context, all: Boolean): Map<String, Any?> {
        val pm = context.packageManager
        val wantAll = all && canListAll()

        val launchable: Set<String> = try {
            val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                pm.queryIntentActivities(intent, 0)
            }.map { it.activityInfo.packageName }.toSet()
        } catch (t: Throwable) {
            emptySet()
        }

        val packages: List<PackageInfo> = try {
            if (wantAll) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    pm.getInstalledPackages(PackageManager.PackageInfoFlags.of(0L))
                } else {
                    @Suppress("DEPRECATION")
                    pm.getInstalledPackages(0)
                }
            } else {
                launchable.mapNotNull { p -> try { pm.getPackageInfo(p, 0) } catch (t: Throwable) { null } }
            }
        } catch (t: Throwable) {
            emptyList()
        }

        val apps = packages.mapNotNull { pi -> describe(pm, pi, launchable) }
            .sortedBy { (it["label"] as String).lowercase() }

        return mapOf(
            "apps" to apps,
            "mode" to if (wantAll) "all" else "launchable",
            "canListAll" to canListAll(),
            // C6 — the UI shows this verbatim when the toggle is locked.
            "allReason" to if (canListAll()) {
                null
            } else {
                "Listing every installed package needs QUERY_ALL_PACKAGES, which Google Play " +
                    "restricts (C6). This build ships without it — install the off-Play (foss) " +
                    "flavour for the full list."
            },
        )
    }

    private fun describe(
        pm: PackageManager,
        pi: PackageInfo,
        launchable: Set<String>,
    ): Map<String, Any?>? = try {
        val ai: ApplicationInfo = pi.applicationInfo ?: return null
        mapOf(
            "package" to pi.packageName,
            "label" to (pm.getApplicationLabel(ai)?.toString() ?: pi.packageName),
            "versionName" to pi.versionName,
            "versionCode" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                pi.longVersionCode
            } else {
                @Suppress("DEPRECATION") pi.versionCode.toLong()
            },
            "targetSdk" to ai.targetSdkVersion,
            "minSdk" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) ai.minSdkVersion else null,
            "system" to ((ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
            "updatedSystem" to ((ai.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0),
            "debuggable" to ((ai.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0),
            "enabled" to ai.enabled,
            "launchable" to launchable.contains(pi.packageName),
            "firstInstall" to pi.firstInstallTime,
            "lastUpdate" to pi.lastUpdateTime,
            "installer" to installerOf(pm, pi.packageName),
            "uid" to ai.uid,
            "dataDir" to ai.dataDir,
            "sourceDir" to ai.sourceDir,
        )
    } catch (t: Throwable) {
        null
    }

    private fun installerOf(pm: PackageManager, pkg: String): String? = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            pm.getInstallSourceInfo(pkg).installingPackageName
        } else {
            @Suppress("DEPRECATION")
            pm.getInstallerPackageName(pkg)
        }
    } catch (t: Throwable) {
        null
    }

    /** Per-app permission list, shown in the inspector detail sheet. */
    fun permissions(context: Context, pkg: String): Map<String, Any?> = try {
        val pi = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.getPackageInfo(
                pkg, PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(pkg, PackageManager.GET_PERMISSIONS)
        }
        val declared = pi.requestedPermissions?.toList() ?: emptyList()
        val flags = pi.requestedPermissionsFlags
        mapOf(
            "ok" to true,
            "permissions" to declared.mapIndexed { i, name ->
                val granted = flags != null && i < flags.size &&
                    (flags[i] and PackageInfo.REQUESTED_PERMISSION_GRANTED) != 0
                mapOf("name" to name, "granted" to granted)
            },
        )
    } catch (t: Throwable) {
        mapOf("ok" to false, "error" to "${t.javaClass.simpleName}: ${t.message}")
    }

    /** Icons are fetched lazily, one package at a time, so a 400-app list stays cheap. */
    fun icon(context: Context, pkg: String, sizePx: Int): ByteArray? = try {
        val d = context.packageManager.getApplicationIcon(pkg)
        val bmp = if (d is BitmapDrawable && d.bitmap != null) {
            Bitmap.createScaledBitmap(d.bitmap, sizePx, sizePx, true)
        } else {
            Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888).also { b ->
                val c = Canvas(b)
                d.setBounds(0, 0, sizePx, sizePx)
                d.draw(c)
            }
        }
        ByteArrayOutputStream().use { out ->
            bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
            out.toByteArray()
        }
    } catch (t: Throwable) {
        null
    }
}
