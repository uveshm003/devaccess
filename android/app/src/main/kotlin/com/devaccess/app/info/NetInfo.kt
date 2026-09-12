package com.devaccess.app.info

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.NetworkCapabilities
import android.net.TrafficStats
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.telephony.TelephonyManager
import com.devaccess.app.bridge.Field
import com.devaccess.app.info.BuildInfo.field
import java.net.Inet4Address
import java.net.Inet6Address

/** Appendix B — Network + Telephony. FR-NET-1..3, FR-MON-5. */
object NetInfo {

    /** The value the framework hands normal apps in place of a real MAC address. */
    private const val ANONYMISED_MAC = "02:00:00:00:00:00"

    private fun cm(context: Context) =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    private fun hasLocation(context: Context): Boolean =
        context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    private fun hasPhoneState(context: Context): Boolean =
        context.checkSelfPermission(Manifest.permission.READ_PHONE_STATE) ==
            PackageManager.PERMISSION_GRANTED

    // ---- connection status (FR-NET-1) -------------------------------------

    fun status(context: Context): Map<String, Any?> {
        val cm = cm(context)
        val network = cm.activeNetwork
        val caps: NetworkCapabilities? = network?.let { cm.getNetworkCapabilities(it) }
        val link: LinkProperties? = network?.let { cm.getLinkProperties(it) }

        val transports = mutableListOf<String>()
        caps?.let { c ->
            if (c.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) transports += "Wi-Fi"
            if (c.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) transports += "Cellular"
            if (c.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) transports += "Ethernet"
            if (c.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) transports += "VPN"
            if (c.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH)) transports += "Bluetooth"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                c.hasTransport(NetworkCapabilities.TRANSPORT_LOWPAN)
            ) transports += "LoWPAN"
        }

        return mapOf(
            "connected" to (caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true &&
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)),
            "hasNetwork" to (network != null),
            "transports" to transports,
            "type" to (transports.firstOrNull() ?: "None"),
            "metered" to (caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) == false),
            "vpn" to (caps?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true),
            "roaming" to (caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_ROAMING) == false),
            "downstreamKbps" to caps?.linkDownstreamBandwidthKbps,
            "upstreamKbps" to caps?.linkUpstreamBandwidthKbps,
            "interface" to link?.interfaceName,
            "ipv4" to link?.linkAddresses?.map { it.address }
                ?.filterIsInstance<Inet4Address>()?.map { it.hostAddress },
            "ipv6" to link?.linkAddresses?.map { it.address }
                ?.filterIsInstance<Inet6Address>()?.map { it.hostAddress },
            "dns" to link?.dnsServers?.mapNotNull { it.hostAddress },
            "domains" to link?.domains,
            "gateway" to link?.routes?.firstOrNull { it.isDefaultRoute }?.gateway?.hostAddress,
            "routes" to link?.routes?.map { it.toString() },
            "mtu" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) link?.mtu else null,
            "privateDns" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                link?.privateDnsServerName ?: if (link?.isPrivateDnsActive == true) "active (opportunistic)" else "off"
            } else null,
        )
    }

    // ---- Wi-Fi (FR-NET-2, C5) ---------------------------------------------

    fun wifi(context: Context): Map<String, Any?> {
        val wm = context.applicationContext
            .getSystemService(Context.WIFI_SERVICE) as? WifiManager
            ?: return mapOf("available" to false, "reason" to "No Wi-Fi service on this device")

        if (!wm.isWifiEnabled) {
            return mapOf("available" to false, "reason" to "Wi-Fi is turned off", "enabled" to false)
        }

        @Suppress("DEPRECATION")
        val info: WifiInfo? = wm.connectionInfo
            ?: return mapOf("available" to false, "reason" to "No Wi-Fi connection info")

        val locationGranted = hasLocation(context)
        val ssidRaw = info?.ssid
        val ssidHidden = ssidRaw == null || ssidRaw == WifiManager.UNKNOWN_SSID || ssidRaw == "<unknown ssid>"

        val freq = info?.frequency ?: -1
        return mapOf(
            "available" to true,
            "enabled" to true,
            "locationGranted" to locationGranted,
            // C5 — from API 27/28 the SSID/BSSID read back as <unknown ssid> / 02:00:… without
            // location permission AND location services switched on.
            "ssid" to if (ssidHidden) null else ssidRaw?.trim('"'),
            "ssidReason" to if (ssidHidden) {
                if (locationGranted) {
                    "SSID hidden — location services must also be switched on (Android 9+)"
                } else {
                    "SSID requires location permission from Android 8.1 (API 27)"
                }
            } else null,
            "bssid" to info?.bssid?.takeIf { it != ANONYMISED_MAC },
            "bssidReason" to if (info?.bssid == ANONYMISED_MAC) {
                "BSSID is redacted without location permission"
            } else null,
            "rssi" to info?.rssi?.takeIf { it != -127 },
            "signalLevel" to info?.rssi?.let {
                @Suppress("DEPRECATION")
                WifiManager.calculateSignalLevel(it, 5)
            },
            "linkSpeed" to info?.linkSpeed?.takeIf { it > 0 },
            "txLinkSpeed" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                info?.txLinkSpeedMbps?.takeIf { it > 0 }
            } else null,
            "rxLinkSpeed" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                info?.rxLinkSpeedMbps?.takeIf { it > 0 }
            } else null,
            "frequency" to freq.takeIf { it > 0 },
            "band" to bandOf(freq),
            "channel" to channelOf(freq),
            "hiddenSsid" to info?.hiddenSSID,
            // getMacAddress() always returns the anonymised sentinel for normal apps (C4);
            // seeing it is how we know MAC randomisation is in force.
            "randomizedMac" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                @Suppress("DEPRECATION")
                (info?.macAddress == ANONYMISED_MAC)
            } else null,
            "macAddress" to "Restricted by OS",
            "standard" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                wifiStandard(info?.wifiStandard ?: 0)
            } else null,
            "networkId" to info?.networkId?.takeIf { it != -1 },
            "5GhzSupported" to wm.is5GHzBandSupported,
            "6GhzSupported" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                wm.is6GHzBandSupported
            } else null,
        )
    }

    private fun bandOf(freq: Int): String? = when {
        freq <= 0 -> null
        freq in 2401..2495 -> "2.4 GHz"
        freq in 4900..5900 -> "5 GHz"
        freq in 5925..7125 -> "6 GHz"
        freq in 57000..71000 -> "60 GHz"
        else -> "$freq MHz"
    }

    private fun channelOf(freq: Int): Int? = when {
        freq <= 0 -> null
        freq == 2484 -> 14
        freq in 2412..2472 -> (freq - 2412) / 5 + 1
        freq in 5170..5825 -> (freq - 5000) / 5
        freq in 5955..7115 -> (freq - 5955) / 5 + 1
        else -> null
    }

    private fun wifiStandard(v: Int): String = when (v) {
        1 -> "802.11 legacy"
        4 -> "802.11n (Wi-Fi 4)"
        5 -> "802.11ac (Wi-Fi 5)"
        6 -> "802.11ax (Wi-Fi 6)"
        7 -> "802.11ad"
        8 -> "802.11be (Wi-Fi 7)"
        else -> "unknown ($v)"
    }

    // ---- telephony (FR-NET-3) ---------------------------------------------

    fun telephony(context: Context): Map<String, Any?> {
        val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            ?: return mapOf("available" to false, "reason" to "No telephony service on this device")

        if (!context.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)) {
            return mapOf("available" to false, "reason" to "Device has no telephony hardware")
        }

        val phoneState = hasPhoneState(context)
        return mapOf(
            "available" to true,
            "phoneStateGranted" to phoneState,
            "carrier" to tm.networkOperatorName?.takeIf { it.isNotBlank() },
            "mccMnc" to tm.networkOperator?.takeIf { it.length >= 5 },
            "mcc" to tm.networkOperator?.takeIf { it.length >= 5 }?.substring(0, 3),
            "mnc" to tm.networkOperator?.takeIf { it.length >= 5 }?.substring(3),
            "simOperator" to tm.simOperatorName?.takeIf { it.isNotBlank() },
            "simCountry" to tm.simCountryIso?.takeIf { it.isNotBlank() },
            "networkCountry" to tm.networkCountryIso?.takeIf { it.isNotBlank() },
            "roaming" to tm.isNetworkRoaming,
            "simState" to simState(tm.simState),
            "phoneType" to when (tm.phoneType) {
                TelephonyManager.PHONE_TYPE_GSM -> "GSM"
                TelephonyManager.PHONE_TYPE_CDMA -> "CDMA"
                TelephonyManager.PHONE_TYPE_SIP -> "SIP"
                else -> "None"
            },
            "simCount" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try { tm.phoneCount } catch (t: Throwable) { null }
            } else null,
            "dataState" to dataState(tm.dataState),
            "dataActivity" to dataActivity(tm.dataActivity),
            // C4/READ_PHONE_STATE — the generation getter is permission-gated from API 30.
            "generation" to if (phoneState || Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                try {
                    @Suppress("DEPRECATION")
                    generationOf(tm.dataNetworkType)
                } catch (t: SecurityException) { null } catch (t: Throwable) { null }
            } else null,
            "generationReason" to if (!phoneState && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                "Network generation requires READ_PHONE_STATE from Android 11 (API 30)"
            } else null,
            "signalStrength" to signalStrength(tm),
            "imei" to null,
            "imeiReason" to "IMEI requires READ_PRIVILEGED_PHONE_STATE (system apps only) from Android 10",
        )
    }

    private fun signalStrength(tm: TelephonyManager): Map<String, Any?>? =
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            null
        } else {
            try {
                tm.signalStrength?.let { ss ->
                    mapOf(
                        "level" to ss.level,
                        "dbm" to ss.cellSignalStrengths.firstOrNull()?.dbm,
                        "asu" to ss.cellSignalStrengths.firstOrNull()?.asuLevel,
                        "detail" to ss.cellSignalStrengths.joinToString("; ") {
                            "${it.javaClass.simpleName.removePrefix("CellSignalStrength")}: ${it.dbm} dBm (L${it.level})"
                        },
                    )
                }
            } catch (t: Throwable) {
                null
            }
        }

    private fun simState(v: Int) = when (v) {
        TelephonyManager.SIM_STATE_ABSENT -> "Absent"
        TelephonyManager.SIM_STATE_READY -> "Ready"
        TelephonyManager.SIM_STATE_PIN_REQUIRED -> "PIN required"
        TelephonyManager.SIM_STATE_PUK_REQUIRED -> "PUK required"
        TelephonyManager.SIM_STATE_NETWORK_LOCKED -> "Network locked"
        TelephonyManager.SIM_STATE_NOT_READY -> "Not ready"
        TelephonyManager.SIM_STATE_PERM_DISABLED -> "Permanently disabled"
        TelephonyManager.SIM_STATE_CARD_IO_ERROR -> "Card I/O error"
        TelephonyManager.SIM_STATE_CARD_RESTRICTED -> "Card restricted"
        else -> "Unknown"
    }

    private fun dataState(v: Int) = when (v) {
        TelephonyManager.DATA_DISCONNECTED -> "Disconnected"
        TelephonyManager.DATA_CONNECTING -> "Connecting"
        TelephonyManager.DATA_CONNECTED -> "Connected"
        TelephonyManager.DATA_SUSPENDED -> "Suspended"
        else -> "Unknown"
    }

    private fun dataActivity(v: Int) = when (v) {
        TelephonyManager.DATA_ACTIVITY_NONE -> "None"
        TelephonyManager.DATA_ACTIVITY_IN -> "In"
        TelephonyManager.DATA_ACTIVITY_OUT -> "Out"
        TelephonyManager.DATA_ACTIVITY_INOUT -> "In/Out"
        TelephonyManager.DATA_ACTIVITY_DORMANT -> "Dormant"
        else -> "Unknown"
    }

    private fun generationOf(networkType: Int): String = when (networkType) {
        TelephonyManager.NETWORK_TYPE_NR -> "5G NR"
        TelephonyManager.NETWORK_TYPE_LTE, TelephonyManager.NETWORK_TYPE_IWLAN -> "4G LTE"
        TelephonyManager.NETWORK_TYPE_HSPAP, TelephonyManager.NETWORK_TYPE_HSPA,
        TelephonyManager.NETWORK_TYPE_HSDPA, TelephonyManager.NETWORK_TYPE_HSUPA,
        TelephonyManager.NETWORK_TYPE_UMTS, TelephonyManager.NETWORK_TYPE_EVDO_0,
        TelephonyManager.NETWORK_TYPE_EVDO_A, TelephonyManager.NETWORK_TYPE_EVDO_B,
        TelephonyManager.NETWORK_TYPE_EHRPD, TelephonyManager.NETWORK_TYPE_TD_SCDMA,
        -> "3G"
        TelephonyManager.NETWORK_TYPE_GPRS, TelephonyManager.NETWORK_TYPE_EDGE,
        TelephonyManager.NETWORK_TYPE_CDMA, TelephonyManager.NETWORK_TYPE_1xRTT,
        TelephonyManager.NETWORK_TYPE_GSM,
        -> "2G"
        else -> "Unknown"
    }

    // ---- throughput (FR-MON-5) --------------------------------------------

    data class Traffic(val totalRx: Long, val totalTx: Long, val uidRx: Long, val uidTx: Long)

    fun traffic(): Traffic {
        val uid = android.os.Process.myUid()
        return Traffic(
            totalRx = TrafficStats.getTotalRxBytes().takeIf { it != TrafficStats.UNSUPPORTED.toLong() } ?: -1,
            totalTx = TrafficStats.getTotalTxBytes().takeIf { it != TrafficStats.UNSUPPORTED.toLong() } ?: -1,
            uidRx = TrafficStats.getUidRxBytes(uid).takeIf { it != TrafficStats.UNSUPPORTED.toLong() } ?: -1,
            uidTx = TrafficStats.getUidTxBytes(uid).takeIf { it != TrafficStats.UNSUPPORTED.toLong() } ?: -1,
        )
    }

    // ---- dashboard fields --------------------------------------------------

    fun networkFields(context: Context): List<Map<String, Any?>> {
        val s = status(context)
        val w = wifi(context)
        val list = mutableListOf<Map<String, Any?>>()

        list += field("type", "Connection type", Field.ok(s["type"]))
        list += field("connected", "Validated internet", Field.ok(s["connected"]))
        list += field("metered", "Metered", Field.ok(s["metered"]))
        list += field("vpn", "VPN active", Field.ok(s["vpn"]))
        list += field("interface", "Interface", nullable(s["interface"], "No active network"))
        list += field("ipv4", "IPv4 addresses", listField(s["ipv4"], "No IPv4 address"), sensitive = true)
        list += field("ipv6", "IPv6 addresses", listField(s["ipv6"], "No IPv6 address"), sensitive = true)
        list += field("gateway", "Default gateway", nullable(s["gateway"], "No default route"), sensitive = true)
        list += field("dns", "DNS servers", listField(s["dns"], "No DNS servers reported"), sensitive = true)
        list += field("privateDns", "Private DNS", nullable(s["privateDns"], "Requires Android 9 (API 28)"))
        list += field("mtu", "MTU", nullable(s["mtu"], "Requires Android 10 (API 29)"))
        list += field("bandwidth", "Reported link bandwidth", Field.ok(
            "↓ ${s["downstreamKbps"] ?: "—"} kbps · ↑ ${s["upstreamKbps"] ?: "—"} kbps",
        ))

        if (w["available"] == true) {
            list += field("ssid", "Wi-Fi SSID",
                (w["ssid"] as? String)?.let { Field.ok(it) }
                    ?: Field.restricted(w["ssidReason"] as? String ?: "Unavailable"),
                sensitive = true)
            list += field("bssid", "Wi-Fi BSSID",
                (w["bssid"] as? String)?.let { Field.ok(it) }
                    ?: Field.restricted(w["bssidReason"] as? String ?: "Unavailable"),
                sensitive = true)
            list += field("rssi", "RSSI", nullable(w["rssi"]?.let { "$it dBm" }, "Not reported"))
            list += field("linkSpeed", "Link speed", nullable(w["linkSpeed"]?.let { "$it Mbps" }, "Not reported"))
            list += field("frequency", "Frequency", nullable(w["frequency"]?.let { "$it MHz" }, "Not reported"))
            list += field("band", "Band", nullable(w["band"], "Not reported"))
            list += field("channel", "Channel", nullable(w["channel"], "Not derivable from this frequency"))
            list += field("standard", "Wi-Fi standard", nullable(w["standard"], "Requires Android 11 (API 30)"))
            list += field("randomizedMac", "Randomised MAC", nullable(w["randomizedMac"], "Requires Android 11 (API 30)"))
            list += field("macAddress", "Wi-Fi MAC", Field.restricted(
                "Device MAC addresses are randomised and unreadable by normal apps from Android 6 (API 23)",
            ), sensitive = true)
        } else {
            list += field("wifi", "Wi-Fi", Field.unavailable(w["reason"] as? String ?: "Unavailable"))
        }

        val t = traffic()
        list += field("rxTotal", "Total received", if (t.totalRx >= 0) Field.ok(t.totalRx) else Field.unavailable("TrafficStats unsupported"))
        list += field("txTotal", "Total transmitted", if (t.totalTx >= 0) Field.ok(t.totalTx) else Field.unavailable("TrafficStats unsupported"))
        list += field("rxApp", "DevAccess received", if (t.uidRx >= 0) Field.ok(t.uidRx) else Field.unavailable("Per-UID stats unsupported"))
        list += field("txApp", "DevAccess transmitted", if (t.uidTx >= 0) Field.ok(t.uidTx) else Field.unavailable("Per-UID stats unsupported"))
        return list
    }

    fun telephonyFields(context: Context): List<Map<String, Any?>> {
        val t = telephony(context)
        if (t["available"] != true) {
            return listOf(field("telephony", "Telephony", Field.unavailable(t["reason"] as? String ?: "Unavailable")))
        }
        @Suppress("UNCHECKED_CAST")
        val sig = t["signalStrength"] as? Map<String, Any?>
        return listOf(
            field("carrier", "Carrier", nullable(t["carrier"], "No carrier reported")),
            field("mccMnc", "MCC/MNC", nullable(t["mccMnc"], "No registered operator"), sensitive = true),
            field("simOperator", "SIM operator", nullable(t["simOperator"], "No SIM")),
            field("simCountry", "SIM country", nullable(t["simCountry"], "No SIM")),
            field("networkCountry", "Network country", nullable(t["networkCountry"], "Not registered")),
            field("simState", "SIM state", Field.ok(t["simState"])),
            field("simCount", "SIM slots", nullable(t["simCount"], "Requires Android 6 (API 23)")),
            field("phoneType", "Phone type", Field.ok(t["phoneType"])),
            field("roaming", "Roaming", Field.ok(t["roaming"])),
            field("generation", "Network generation",
                (t["generation"] as? String)?.let { Field.ok(it) }
                    ?: Field.restricted(t["generationReason"] as? String ?: "Unavailable")),
            field("dataState", "Data state", Field.ok(t["dataState"])),
            field("dataActivity", "Data activity", Field.ok(t["dataActivity"])),
            field("signalLevel", "Signal level", nullable(sig?.get("level")?.let { "$it / 4" }, "Requires Android 9 (API 28)")),
            field("signalDbm", "Signal strength", nullable(sig?.get("dbm")?.let { "$it dBm" }, "Requires Android 9 (API 28)")),
            field("signalDetail", "Signal detail", nullable(sig?.get("detail"), "Requires Android 9 (API 28)")),
            field("imei", "IMEI / MEID", Field.restricted(t["imeiReason"] as String), sensitive = true),
        )
    }

    private fun nullable(v: Any?, whenNull: String): Map<String, Any?> =
        if (v == null) Field.restricted(whenNull) else Field.ok(v)

    private fun listField(v: Any?, whenEmpty: String): Map<String, Any?> {
        val list = v as? List<*> ?: return Field.restricted(whenEmpty)
        return if (list.isEmpty()) Field.restricted(whenEmpty) else Field.ok(list.joinToString(", "))
    }
}
