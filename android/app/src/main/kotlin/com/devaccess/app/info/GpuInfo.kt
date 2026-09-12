package com.devaccess.app.info

import android.content.Context
import android.content.pm.PackageManager
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES20
import com.devaccess.app.bridge.Field
import com.devaccess.app.info.BuildInfo.field

/**
 * Appendix B — GPU. GL_RENDERER/GL_VENDOR only exist inside a current GL context, so a
 * throwaway 1×1 pbuffer context is created, queried and torn down. Cached: it is not free.
 */
object GpuInfo {

    private data class Gl(
        val renderer: String?,
        val vendor: String?,
        val version: String?,
        val glslVersion: String?,
        val extensions: String?,
    )

    @Volatile private var cached: Gl? = null
    @Volatile private var failure: String? = null

    private fun query(): Gl? {
        cached?.let { return it }
        failure?.let { return null }

        var display: EGLDisplay? = null
        var context: EGLContext? = null
        var surface: EGLSurface? = null
        return try {
            display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
            check(display != EGL14.EGL_NO_DISPLAY) { "no EGL display" }
            val version = IntArray(2)
            check(EGL14.eglInitialize(display, version, 0, version, 1)) { "eglInitialize failed" }

            val attribs = intArrayOf(
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT,
                EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_NONE,
            )
            val configs = arrayOfNulls<EGLConfig>(1)
            val num = IntArray(1)
            check(EGL14.eglChooseConfig(display, attribs, 0, configs, 0, 1, num, 0) && num[0] > 0) {
                "no suitable EGL config"
            }
            context = EGL14.eglCreateContext(
                display, configs[0], EGL14.EGL_NO_CONTEXT,
                intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0,
            )
            check(context != EGL14.EGL_NO_CONTEXT) { "eglCreateContext failed" }
            surface = EGL14.eglCreatePbufferSurface(
                display, configs[0],
                intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE), 0,
            )
            check(EGL14.eglMakeCurrent(display, surface, surface, context)) { "eglMakeCurrent failed" }

            val gl = Gl(
                renderer = GLES20.glGetString(GLES20.GL_RENDERER),
                vendor = GLES20.glGetString(GLES20.GL_VENDOR),
                version = GLES20.glGetString(GLES20.GL_VERSION),
                glslVersion = GLES20.glGetString(GLES20.GL_SHADING_LANGUAGE_VERSION),
                extensions = GLES20.glGetString(GLES20.GL_EXTENSIONS),
            )
            cached = gl
            gl
        } catch (t: Throwable) {
            failure = t.message ?: t.javaClass.simpleName
            null
        } finally {
            try {
                if (display != null) {
                    EGL14.eglMakeCurrent(
                        display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT,
                    )
                    if (surface != null) EGL14.eglDestroySurface(display, surface)
                    if (context != null) EGL14.eglDestroyContext(display, context)
                    EGL14.eglTerminate(display)
                }
            } catch (_: Throwable) {
                // Teardown failures are not worth surfacing.
            }
        }
    }

    fun fields(context: Context): List<Map<String, Any?>> {
        val gl = query()
        val failReason = failure ?: "GL context could not be created"
        fun glField(key: String, label: String, value: String?) = field(
            key, label,
            value?.let { Field.ok(it) } ?: Field.unavailable(failReason),
        )

        val pm = context.packageManager
        return listOf(
            glField("renderer", "Renderer", gl?.renderer),
            glField("vendor", "Vendor", gl?.vendor),
            glField("glVersion", "OpenGL ES version", gl?.version),
            glField("glsl", "GLSL version", gl?.glslVersion),
            field("esFeature", "Declared ES version", Field.of {
                val cm = context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                val v = cm.deviceConfigurationInfo.reqGlEsVersion
                "%d.%d".format(v shr 16, v and 0xFFFF)
            }),
            field("vulkan", "Vulkan support", vulkan(pm)),
            field("vulkanCompute", "Vulkan compute level", featureVersion(pm, PackageManager.FEATURE_VULKAN_HARDWARE_COMPUTE)),
            field("vulkanLevel", "Vulkan hardware level", featureVersion(pm, PackageManager.FEATURE_VULKAN_HARDWARE_LEVEL)),
            field("extensionCount", "GL extensions", gl?.extensions
                ?.split(" ")?.filter { it.isNotBlank() }?.size
                ?.let { Field.ok("$it extensions") }
                ?: Field.unavailable(failReason)),
            field("extensions", "GL extension list", gl?.extensions
                ?.split(" ")?.filter { it.isNotBlank() }?.sorted()?.joinToString("\n")
                ?.let { Field.ok(it) }
                ?: Field.unavailable(failReason)),
        )
    }

    private fun vulkan(pm: PackageManager): Map<String, Any?> {
        if (!pm.hasSystemFeature(PackageManager.FEATURE_VULKAN_HARDWARE_VERSION)) {
            return Field.ok("not supported")
        }
        val version = pm.systemAvailableFeatures
            .firstOrNull { it.name == PackageManager.FEATURE_VULKAN_HARDWARE_VERSION }
            ?.version
            ?: return Field.ok("supported (version not reported)")
        // Packed as major<<22 | minor<<12 | patch.
        return Field.ok(
            "%d.%d.%d".format(version shr 22, (version shr 12) and 0x3FF, version and 0xFFF),
        )
    }

    private fun featureVersion(pm: PackageManager, name: String): Map<String, Any?> {
        if (!pm.hasSystemFeature(name)) return Field.ok("not supported")
        val v = pm.systemAvailableFeatures.firstOrNull { it.name == name }?.version
        return Field.ok(v?.toString() ?: "supported")
    }
}
