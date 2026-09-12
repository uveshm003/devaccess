package com.devaccess.app.net

import com.devaccess.app.util.Sys
import java.io.IOException
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.net.URL
import java.net.UnknownHostException
import javax.net.ssl.HttpsURLConnection

/**
 * FR-NET-4 — ping, traceroute, DNS lookup, reachability and an HTTP latency test.
 *
 * ICMP sockets are privileged on Android, so ping/traceroute shell out to the platform
 * binaries (an ordinary app may execute them). Where a binary is missing the tool reports
 * that plainly instead of faking a result.
 */
object NetTools {

    fun interface Sink {
        fun emit(event: Map<String, Any?>)
    }

    private fun line(text: String) = mapOf("type" to "line", "text" to text)
    private fun done(ok: Boolean, summary: String?) =
        mapOf("type" to "done", "ok" to ok, "summary" to summary)

    private fun err(text: String) = mapOf("type" to "error", "text" to text)

    // ---- ping --------------------------------------------------------------

    fun ping(host: String, count: Int, sink: Sink, cancelled: () -> Boolean) {
        val bin = Sys.which("ping")
        if (bin == null) {
            fallbackPing(host, count, sink, cancelled)
            return
        }
        sink.emit(line("$ ping -c $count $host"))
        val rtts = mutableListOf<Double>()
        val code = Sys.execStreaming(
            listOf(bin, "-c", count.toString(), "-W", "3", host),
            timeoutMs = (count * 2000L + 6000L),
            onLine = { l ->
                sink.emit(line(l))
                Regex("time=([0-9.]+)").find(l)?.groupValues?.get(1)?.toDoubleOrNull()?.let { rtts += it }
            },
            isCancelled = cancelled,
        )
        val summary = if (rtts.isEmpty()) {
            "No replies received"
        } else {
            "%d/%d replies · min %.1f ms · avg %.1f ms · max %.1f ms".format(
                rtts.size, count, rtts.min(), rtts.average(), rtts.max(),
            )
        }
        sink.emit(done(code == 0 || rtts.isNotEmpty(), summary))
    }

    /** No ping binary: time TCP connects to port 443/80 instead and say so. */
    private fun fallbackPing(host: String, count: Int, sink: Sink, cancelled: () -> Boolean) {
        sink.emit(line("ping binary not found — falling back to TCP connect timing"))
        val rtts = mutableListOf<Double>()
        repeat(count) { i ->
            if (cancelled()) return
            val r = tcpProbe(host, 443, 3000).takeIf { it >= 0 } ?: tcpProbe(host, 80, 3000)
            if (r >= 0) {
                rtts += r.toDouble()
                sink.emit(line("seq=${i + 1} tcp connect time=$r ms"))
            } else {
                sink.emit(line("seq=${i + 1} no response"))
            }
        }
        sink.emit(
            done(
                rtts.isNotEmpty(),
                if (rtts.isEmpty()) "No TCP responses" else "avg %.1f ms over %d probes".format(rtts.average(), rtts.size),
            ),
        )
    }

    private fun tcpProbe(host: String, port: Int, timeoutMs: Int): Long = try {
        val start = System.nanoTime()
        Socket().use { s ->
            s.connect(InetSocketAddress(host, port), timeoutMs)
        }
        (System.nanoTime() - start) / 1_000_000
    } catch (t: Throwable) {
        -1
    }

    // ---- traceroute --------------------------------------------------------

    fun traceroute(host: String, maxHops: Int, sink: Sink, cancelled: () -> Boolean) {
        val bin = Sys.which("traceroute")
        if (bin != null) {
            sink.emit(line("$ traceroute -m $maxHops $host"))
            val code = Sys.execStreaming(
                listOf(bin, "-m", maxHops.toString(), "-w", "2", host),
                timeoutMs = maxHops * 3000L + 5000L,
                onLine = { sink.emit(line(it)) },
                isCancelled = cancelled,
            )
            sink.emit(done(code == 0, null))
            return
        }
        // Android ships ping with a -t (TTL) flag on most builds; walk the TTL and read the
        // "From <hop>" line each ICMP time-exceeded reply carries.
        val pingBin = Sys.which("ping")
        if (pingBin == null) {
            sink.emit(err(
                "Neither traceroute nor ping is present on this device, and raw ICMP sockets " +
                    "are privileged on Android — traceroute is unavailable here.",
            ))
            sink.emit(done(false, null))
            return
        }
        sink.emit(line("traceroute binary not found — walking TTLs with ping"))
        var reached = false
        for (ttl in 1..maxHops) {
            if (cancelled()) break
            val r = Sys.exec(listOf(pingBin, "-c", "1", "-t", ttl.toString(), "-W", "2", host), 4000)
            val text = r.stdout + r.stderr
            val hop = Regex("From ([0-9a-fA-F:.]+)").find(text)?.groupValues?.get(1)
                ?: Regex("from ([0-9a-fA-F:.]+)").find(text)?.groupValues?.get(1)
            val rtt = Regex("time=([0-9.]+)").find(text)?.groupValues?.get(1)
            when {
                r.ok && rtt != null -> {
                    sink.emit(line("%2d  %s  %s ms  (destination)".format(ttl, host, rtt)))
                    reached = true
                }
                hop != null -> sink.emit(line("%2d  %s".format(ttl, hop)))
                else -> sink.emit(line("%2d  *".format(ttl)))
            }
            if (reached) break
        }
        sink.emit(done(reached, if (reached) "Destination reached" else "Destination not reached"))
    }

    // ---- DNS ---------------------------------------------------------------

    fun dns(host: String): Map<String, Any?> = try {
        val start = System.nanoTime()
        val addrs = InetAddress.getAllByName(host)
        val ms = (System.nanoTime() - start) / 1_000_000.0
        mapOf(
            "ok" to true,
            "host" to host,
            "ms" to ms,
            "addresses" to addrs.map {
                mapOf(
                    "address" to it.hostAddress,
                    "family" to if (it is java.net.Inet6Address) "IPv6" else "IPv4",
                    "canonical" to it.canonicalHostName,
                )
            },
        )
    } catch (t: UnknownHostException) {
        mapOf("ok" to false, "host" to host, "error" to "No DNS record for '$host'")
    } catch (t: Throwable) {
        mapOf("ok" to false, "host" to host, "error" to "${t.javaClass.simpleName}: ${t.message}")
    }

    // ---- reachability ------------------------------------------------------

    fun reach(host: String, port: Int, timeoutMs: Int): Map<String, Any?> {
        val start = System.nanoTime()
        return try {
            Socket().use { it.connect(InetSocketAddress(host, port), timeoutMs) }
            mapOf("ok" to true, "host" to host, "port" to port,
                "ms" to (System.nanoTime() - start) / 1_000_000.0)
        } catch (t: IOException) {
            mapOf("ok" to false, "host" to host, "port" to port,
                "error" to (t.message ?: "Connection failed"),
                "ms" to (System.nanoTime() - start) / 1_000_000.0)
        } catch (t: Throwable) {
            mapOf("ok" to false, "host" to host, "port" to port,
                "error" to "${t.javaClass.simpleName}: ${t.message}")
        }
    }

    // ---- HTTP latency ------------------------------------------------------

    fun http(urlString: String, method: String): Map<String, Any?> {
        var conn: HttpURLConnection? = null
        return try {
            val url = URL(urlString)
            val dnsStart = System.nanoTime()
            InetAddress.getByName(url.host)
            val dnsMs = (System.nanoTime() - dnsStart) / 1_000_000.0

            val start = System.nanoTime()
            conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = method
                connectTimeout = 8000
                readTimeout = 8000
                instanceFollowRedirects = false
                setRequestProperty("User-Agent", "DevAccess/1.0")
            }
            conn.connect()
            val connectMs = (System.nanoTime() - start) / 1_000_000.0
            val code = conn.responseCode
            val bytes = if (method == "GET") {
                conn.inputStream.use { it.readBytes().size }
            } else {
                0
            }
            val totalMs = (System.nanoTime() - start) / 1_000_000.0
            mapOf(
                "ok" to true,
                "url" to urlString,
                "code" to code,
                "message" to conn.responseMessage,
                "dnsMs" to dnsMs,
                "connectMs" to connectMs,
                "totalMs" to totalMs,
                "bytes" to bytes,
                "tls" to (conn is HttpsURLConnection),
                "server" to conn.getHeaderField("Server"),
                "contentType" to conn.contentType,
            )
        } catch (t: Throwable) {
            mapOf("ok" to false, "url" to urlString,
                "error" to "${t.javaClass.simpleName}: ${t.message}")
        } finally {
            try { conn?.disconnect() } catch (_: Throwable) {}
        }
    }
}
