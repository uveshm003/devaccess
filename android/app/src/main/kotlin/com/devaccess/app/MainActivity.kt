package com.devaccess.app

import android.content.Intent
import android.os.Bundle
import com.devaccess.app.bridge.Channels
import com.devaccess.app.bridge.MethodRouter
import com.devaccess.app.bridge.MonitorStreamHandler
import com.devaccess.app.bridge.NetToolStreamHandler
import com.devaccess.app.bridge.SensorStreamHandler
import com.devaccess.app.report.Exporter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter UI and wires up the platform channels (T-ARCH-1).
 *
 * Also routes deep entries — a Quick Settings tile, a launcher shortcut or the monitor
 * notification hand a route name in through [EXTRA_ROUTE], which Dart picks up on startup
 * and on later `onNewIntent` deliveries.
 */
class MainActivity : FlutterActivity() {

    companion object {
        const val EXTRA_ROUTE = "devaccess.route"
        const val EXTRA_TARGET = "devaccess.target"
    }

    private var router: MethodRouter? = null
    private var methodChannel: MethodChannel? = null
    private var netHandler: NetToolStreamHandler? = null
    private val eventChannels = mutableListOf<EventChannel>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        val r = MethodRouter(applicationContext) { this }
        router = r
        methodChannel = MethodChannel(messenger, Channels.METHOD).apply { setMethodCallHandler(r) }

        eventChannels += EventChannel(messenger, Channels.EVENT_MONITOR)
            .apply { setStreamHandler(MonitorStreamHandler(applicationContext)) }
        eventChannels += EventChannel(messenger, Channels.EVENT_SENSORS)
            .apply { setStreamHandler(SensorStreamHandler(applicationContext)) }
        netHandler = NetToolStreamHandler()
        eventChannels += EventChannel(messenger, Channels.EVENT_NET)
            .apply { setStreamHandler(netHandler) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The route from the launching intent is delivered once Dart asks for it.
        deliverRoute(intent, immediate = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        deliverRoute(intent, immediate = true)
    }

    private fun deliverRoute(intent: Intent?, immediate: Boolean) {
        val route = intent?.getStringExtra(EXTRA_ROUTE) ?: return
        val payload = mapOf("route" to route, "target" to intent.getStringExtra(EXTRA_TARGET))
        if (immediate) {
            methodChannel?.invokeMethod("app.route", payload)
        } else {
            // Dart is not listening yet during onCreate; post after the first frame.
            window.decorView.post { methodChannel?.invokeMethod("app.route", payload) }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == Exporter.REQUEST_CREATE_DOCUMENT) {
            router?.onSaveResult(resultCode, data)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        router?.onPermissionResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        methodChannel?.setMethodCallHandler(null)
        // Clearing a handler cancels any live subscription, which stops the sampling loop
        // and unregisters sensor listeners.
        eventChannels.forEach { it.setStreamHandler(null) }
        eventChannels.clear()
        netHandler?.dispose()
        router?.dispose()
        router = null
        super.onDestroy()
    }
}
