package com.devaccess.app.util

import android.os.Build
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.util.concurrent.TimeUnit

/** Low-level system helpers shared by the info providers. Nothing here may throw. */
object Sys {

    /** Reads `ro.*` build properties that are not mirrored onto [Build]. */
    fun prop(key: String): String? = try {
        @Suppress("PrivateApi")
        val c = Class.forName("android.os.SystemProperties")
        val m = c.getMethod("get", String::class.java, String::class.java)
        (m.invoke(null, key, "") as? String)?.takeIf { it.isNotBlank() }
    } catch (t: Throwable) {
        // Fall back to the getprop binary; on some builds reflection is blocked.
        exec(listOf("getprop", key), 1500).stdout.trim().takeIf { it.isNotBlank() }
    }

    fun readFile(path: String): String? = try {
        val f = File(path)
        if (f.canRead()) f.readText().trim().takeIf { it.isNotEmpty() } else null
    } catch (t: Throwable) {
        null
    }

    fun readLong(path: String): Long? = readFile(path)?.trim()?.toLongOrNull()

    fun listDir(path: String, prefix: String): List<File> = try {
        File(path).listFiles { f -> f.name.startsWith(prefix) }?.sortedBy { it.name } ?: emptyList()
    } catch (t: Throwable) {
        emptyList()
    }

    data class ExecResult(val code: Int, val stdout: String, val stderr: String) {
        val ok: Boolean get() = code == 0
    }

    /**
     * Runs a normal (non-root) command. Used for `getprop`, `ping`, `getenforce` and friends,
     * all of which are executable by an ordinary app. Times out rather than hanging the caller.
     */
    fun exec(cmd: List<String>, timeoutMs: Long = 5000): ExecResult = try {
        val p = ProcessBuilder(cmd).redirectErrorStream(false).start()
        val out = StringBuilder()
        val err = StringBuilder()
        val tOut = Thread { p.inputStream.bufferedReader().forEachLine { out.appendLine(it) } }
        val tErr = Thread { p.errorStream.bufferedReader().forEachLine { err.appendLine(it) } }
        tOut.start(); tErr.start()
        val finished = p.waitFor(timeoutMs, TimeUnit.MILLISECONDS)
        if (!finished) p.destroyForcibly()
        tOut.join(500); tErr.join(500)
        ExecResult(if (finished) p.exitValue() else -1, out.toString(), err.toString())
    } catch (t: Throwable) {
        ExecResult(-1, "", t.message ?: t.javaClass.simpleName)
    }

    /**
     * Streams a command's output line by line. Returns the exit code.
     * Used by the network tools so ping/traceroute results appear as they arrive.
     */
    fun execStreaming(
        cmd: List<String>,
        timeoutMs: Long,
        onLine: (String) -> Unit,
        isCancelled: () -> Boolean,
    ): Int = try {
        val p = ProcessBuilder(cmd).redirectErrorStream(true).start()
        val reader = BufferedReader(InputStreamReader(p.inputStream))
        val deadline = System.currentTimeMillis() + timeoutMs
        var line: String?
        while (true) {
            if (isCancelled() || System.currentTimeMillis() > deadline) {
                p.destroyForcibly()
                break
            }
            line = reader.readLine() ?: break
            onLine(line)
        }
        try { reader.close() } catch (_: Throwable) {}
        if (p.waitFor(1000, TimeUnit.MILLISECONDS)) p.exitValue() else { p.destroyForcibly(); -1 }
    } catch (t: Throwable) {
        onLine("error: ${t.message ?: t.javaClass.simpleName}")
        -1
    }

    fun sdkInt(): Int = Build.VERSION.SDK_INT

    fun which(name: String): String? =
        listOf("/system/bin/$name", "/system/xbin/$name", "/vendor/bin/$name")
            .firstOrNull { File(it).canExecute() }
}
