import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The Dart half of the platform-channel contract (T-ARCH-1).
///
/// Mirrors `com.devaccess.app.bridge.Channels`. One [MethodChannel] for
/// request/response work and three [EventChannel]s for the streaming surfaces.
///
/// NFR-RELIABILITY-1 — every call is wrapped: a `PlatformException`, a missing
/// implementation or a channel error becomes a [BridgeFailure] the caller can render as a
/// labelled "unavailable" state. Nothing here rethrows into the widget tree.
class DevAccessBridge {
  DevAccessBridge._();

  static final DevAccessBridge instance = DevAccessBridge._();

  static const MethodChannel _method = MethodChannel('dev.access/method');
  static const EventChannel _monitorEvents = EventChannel('dev.access/events/monitor');
  static const EventChannel _sensorEvents = EventChannel('dev.access/events/sensors');
  static const EventChannel _netEvents = EventChannel('dev.access/events/net');

  final _routeController = StreamController<NativeRoute>.broadcast();

  /// Routes pushed in from a Quick Settings tile, a launcher shortcut or the monitor
  /// notification (FR-SURF-1/3).
  Stream<NativeRoute> get routes => _routeController.stream;

  bool _routingReady = false;

  void startListeningForRoutes() {
    if (_routingReady) return;
    _routingReady = true;
    _method.setMethodCallHandler((call) async {
      if (call.method == 'app.route') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        _routeController.add(
          NativeRoute(args['route'] as String? ?? 'home', args['target'] as String?),
        );
      }
      return null;
    });
  }

  /// Invokes [method] and returns `null` instead of throwing when the platform fails.
  Future<T?> _call<T>(String method, [Map<String, dynamic>? args]) async {
    try {
      return await _method.invokeMethod<T>(method, args);
    } on MissingPluginException {
      debugPrint('DevAccess: no native implementation for $method');
      return null;
    } on PlatformException catch (e) {
      debugPrint('DevAccess: $method failed — ${e.code}: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('DevAccess: $method failed — $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _map(String method, [Map<String, dynamic>? args]) async {
    final raw = await _call<Map<Object?, Object?>>(method, args);
    if (raw == null) return const {};
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }

  Future<List<Map<String, dynamic>>> _list(String method, [Map<String, dynamic>? args]) async {
    final raw = await _call<List<Object?>>(method, args);
    if (raw == null) return const [];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList(growable: false);
  }

  // ---- app / tier ---------------------------------------------------------

  Future<Map<String, dynamic>> appInfo() => _map('app.info');

  /// FR-SET-1 — the wallpaper-derived seed colour on Android 12+, or null below it.
  Future<Color?> dynamicColorSeed() async {
    final argb = await _call<int>('app.dynamicColor');
    return argb == null ? null : Color(argb);
  }

  Future<Map<String, dynamic>> tierStatus({bool probeRoot = false}) =>
      _map('tier.status', {'probeRoot': probeRoot});

  Future<void> resetRootProbe() => _call<bool>('tier.resetRootProbe');

  Future<Map<String, dynamic>> requestWriteSettings() => _map('tier.requestWriteSettings');

  Future<Map<String, dynamic>> detectEmulator() => _map('emulator.detect');

  // ---- settings -----------------------------------------------------------

  Future<Map<String, dynamic>> readSetting(String scope, String key) =>
      _map('settings.read', {'scope': scope, 'key': key});

  Future<List<Map<String, dynamic>>> readSettings(List<Map<String, String>> items) =>
      _list('settings.readMany', {'items': items});

  Future<Map<String, dynamic>> writeSetting({
    required String scope,
    required String key,
    required String value,
    required String type,
    bool allowRoot = true,
  }) =>
      _map('settings.write', {
        'scope': scope,
        'key': key,
        'value': value,
        'type': type,
        'allowRoot': allowRoot,
      });

  Future<Map<String, dynamic>> setDemoMode(bool enabled, [Map<String, String>? preset]) =>
      _map('settings.demoMode', {'enabled': enabled, 'preset': preset});

  Future<Map<String, dynamic>> setProp(String key, String value) =>
      _map('settings.setProp', {'key': key, 'value': value});

  // ---- intents ------------------------------------------------------------

  Future<Map<String, dynamic>> launchChain(List<Map<String, dynamic>> chain) =>
      _map('intent.launch', {'chain': chain});

  Future<List<bool>> resolveMany(List<Map<String, dynamic>> specs) async {
    final raw = await _call<List<Object?>>('intent.resolveMany', {'specs': specs});
    if (raw == null) return List<bool>.filled(specs.length, false);
    return raw.map((e) => e == true).toList(growable: false);
  }

  Future<Map<String, dynamic>> openAppScreen(String package, String screen) =>
      _map('intent.appScreen', {'package': package, 'screen': screen});

  Future<Map<String, dynamic>> customIntent(Map<String, dynamic> spec) =>
      _map('intent.custom', spec);

  // ---- device info --------------------------------------------------------

  Future<List<Map<String, dynamic>>> infoIndex() => _list('info.index');

  Future<Map<String, dynamic>> infoSection(String id) => _map('info.section', {'id': id});

  Future<List<Map<String, dynamic>>> infoAll() => _list('info.all');

  // ---- sensors / cameras --------------------------------------------------

  Future<List<Map<String, dynamic>>> sensors() => _list('sensors.list');

  Future<List<Map<String, dynamic>>> cameras() => _list('cameras.list');

  Stream<Map<String, dynamic>> sensorStream(int type, {int delayUs = 30000}) =>
      _sensorEvents
          .receiveBroadcastStream({'type': type, 'delayUs': delayUs})
          .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)));

  // ---- network ------------------------------------------------------------

  Future<Map<String, dynamic>> netStatus() => _map('net.status');

  Future<Map<String, dynamic>> wifiInfo() => _map('net.wifi');

  Future<Map<String, dynamic>> telephonyInfo() => _map('net.telephony');

  Future<Map<String, dynamic>> dnsLookup(String host) => _map('net.dns', {'host': host});

  Future<Map<String, dynamic>> reachability(String host, int port, {int timeoutMs = 4000}) =>
      _map('net.reach', {'host': host, 'port': port, 'timeoutMs': timeoutMs});

  Future<Map<String, dynamic>> httpTest(String url, {String method = 'GET'}) =>
      _map('net.http', {'url': url, 'method': method});

  Stream<Map<String, dynamic>> netTool(Map<String, dynamic> args) => _netEvents
      .receiveBroadcastStream(args)
      .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)));

  // ---- apps ---------------------------------------------------------------

  Future<Map<String, dynamic>> appsList({bool all = false}) => _map('apps.list', {'all': all});

  Future<Map<String, dynamic>> appPermissions(String package) =>
      _map('apps.permissions', {'package': package});

  Future<Uint8List?> appIcon(String package, {int size = 96}) =>
      _call<Uint8List>('apps.icon', {'package': package, 'size': size});

  // ---- monitoring ---------------------------------------------------------

  Future<Map<String, dynamic>> monitorSnapshot() => _map('monitor.snapshot');

  Future<void> setMonitorInterval(int intervalMs) =>
      _call<bool>('monitor.setInterval', {'intervalMs': intervalMs});

  Future<void> setMonitorPaused(bool paused) =>
      _call<bool>('monitor.setPaused', {'paused': paused});

  Future<void> startMonitorService(int intervalMs) =>
      _call<bool>('monitor.startService', {'intervalMs': intervalMs});

  Future<void> stopMonitorService() => _call<bool>('monitor.stopService');

  Future<bool> monitorServiceRunning() async =>
      await _call<bool>('monitor.serviceRunning') ?? false;

  Stream<Map<String, dynamic>> monitorStream({int intervalMs = 1000}) => _monitorEvents
      .receiveBroadcastStream({'intervalMs': intervalMs})
      .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)));

  // ---- overlay ------------------------------------------------------------

  Future<Map<String, dynamic>> overlayStatus() => _map('overlay.status');

  Future<Map<String, dynamic>> requestOverlayPermission() => _map('overlay.requestPermission');

  Future<Map<String, dynamic>> startOverlay() => _map('overlay.start');

  Future<Map<String, dynamic>> stopOverlay() => _map('overlay.stop');

  // ---- permissions --------------------------------------------------------

  Future<Map<String, bool>> permissionStatus(List<String> permissions) async {
    final raw = await _map('perm.status', {'permissions': permissions});
    return raw.map((k, v) => MapEntry(k, v == true));
  }

  Future<Map<String, bool>> requestPermissions(List<String> permissions) async {
    final raw = await _map('perm.request', {'permissions': permissions});
    return raw.map((k, v) => MapEntry(k, v == true));
  }

  Future<Map<String, dynamic>> openSpecialAccess(String which) =>
      _map('perm.openSpecial', {'which': which});

  // ---- reporting ----------------------------------------------------------

  Future<Map<String, dynamic>> shareText(String text, {String? subject}) =>
      _map('share.text', {'text': text, 'subject': subject});

  Future<Map<String, dynamic>> shareFile({
    required String name,
    required String mime,
    required Uint8List bytes,
    String? subject,
  }) =>
      _map('share.file', {'name': name, 'mime': mime, 'bytes': bytes, 'subject': subject});

  Future<Map<String, dynamic>> saveFile({
    required String name,
    required String mime,
    required Uint8List bytes,
  }) =>
      _map('file.save', {'name': name, 'mime': mime, 'bytes': bytes});

  Future<Uint8List?> renderPdf({required String title, required String body}) =>
      _call<Uint8List>('report.pdf', {'title': title, 'body': body});

  // ---- surfaces -----------------------------------------------------------

  Future<Map<String, dynamic>> setShortcuts(List<Map<String, dynamic>> items) =>
      _map('surface.setShortcuts', {'items': items});

  Future<void> refreshWidgets() => _call<bool>('surface.refreshWidgets');

  // ---- preferences --------------------------------------------------------

  Future<String?> loadPrefs() => _call<String>('prefs.load');

  Future<bool> savePrefs(String json) async => await _call<bool>('prefs.save', {'json': json}) ?? false;

  Future<bool> clearPrefs() async => await _call<bool>('prefs.clear') ?? false;
}

/// A navigation request arriving from a native surface.
@immutable
class NativeRoute {
  const NativeRoute(this.route, this.target);

  final String route;
  final String? target;
}

/// Android permission names used by the contextual permission flows (FR-PERM-1).
abstract final class AndroidPermissions {
  static const fineLocation = 'android.permission.ACCESS_FINE_LOCATION';
  static const coarseLocation = 'android.permission.ACCESS_COARSE_LOCATION';
  static const bluetoothConnect = 'android.permission.BLUETOOTH_CONNECT';
  static const readPhoneState = 'android.permission.READ_PHONE_STATE';
  static const postNotifications = 'android.permission.POST_NOTIFICATIONS';
}
