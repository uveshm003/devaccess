import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';

import '../models/monitor.dart';
import '../platform/channels.dart';

/// A bounded ring of recent values, used for the sparkline graphs.
class SeriesBuffer {
  SeriesBuffer(this.capacity);

  final int capacity;
  final Queue<double> _values = Queue<double>();

  void add(double? value) {
    if (value == null || value.isNaN || value.isInfinite) return;
    _values.addLast(value);
    while (_values.length > capacity) {
      _values.removeFirst();
    }
  }

  List<double> get values => List<double>.unmodifiable(_values);

  bool get isEmpty => _values.isEmpty;

  double get latest => _values.isEmpty ? 0 : _values.last;

  double get max => _values.isEmpty ? 0 : _values.reduce((a, b) => a > b ? a : b);

  void clear() => _values.clear();
}

/// FR-MON-1..7 — owns the live sampling subscription and the rolling history.
///
/// NFR-PERF-2 — sampling is paused whenever the app is backgrounded or the monitor view
/// is not on screen, unless the user has explicitly started the persistent service.
class MonitorController extends ChangeNotifier with WidgetsBindingObserver {
  MonitorController(this._bridge);

  final DevAccessBridge _bridge;

  static const int historyLength = 90;

  StreamSubscription<Map<String, dynamic>>? _sub;
  MonitorSample? _latest;
  int _intervalMs = 1000;
  int _viewers = 0;
  bool _serviceRunning = false;
  bool _overlayGranted = false;
  bool _overlayRunning = false;
  String? _error;

  final cpuHistory = SeriesBuffer(historyLength);
  final memoryHistory = SeriesBuffer(historyLength);
  final batteryTempHistory = SeriesBuffer(historyLength);
  final rxHistory = SeriesBuffer(historyLength);
  final txHistory = SeriesBuffer(historyLength);

  MonitorSample? get latest => _latest;

  bool get streaming => _sub != null;

  bool get serviceRunning => _serviceRunning;

  bool get overlayGranted => _overlayGranted;

  bool get overlayRunning => _overlayRunning;

  String? get error => _error;

  int get intervalMs => _intervalMs;

  void attach() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Called when a monitoring view becomes visible.
  void addViewer(int intervalMs) {
    _viewers++;
    _intervalMs = intervalMs;
    _start();
  }

  /// Called when a monitoring view is dismissed (FR-MON-7 — stop cleanly).
  void removeViewer() {
    _viewers = (_viewers - 1).clamp(0, 1 << 30);
    if (_viewers == 0 && !_serviceRunning) _stop();
  }

  void _start() {
    if (_sub != null) return;
    _error = null;
    _sub = _bridge.monitorStream(intervalMs: _intervalMs).listen(
      (raw) {
        final sample = MonitorSample.fromMap(raw);
        _latest = sample;
        cpuHistory.add(sample.cpuLoad);
        memoryHistory.add(sample.memTotal > 0 ? sample.memFraction * 100 : null);
        batteryTempHistory.add(sample.batteryTempC);
        rxHistory.add(sample.rxPerSec);
        txHistory.add(sample.txPerSec);
        notifyListeners();
      },
      onError: (Object e) {
        _error = e.toString();
        notifyListeners();
      },
      cancelOnError: false,
    );
    notifyListeners();
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    // The monitor view calls removeViewer() from `deactivate`, which the framework runs
    // mid-unmount. Notifying synchronously there tries to dirty a widget during the build
    // phase and trips an assertion, so the rebuild is deferred by one microtask.
    _notifyDeferred();
  }

  bool _disposed = false;

  void _notifyDeferred() {
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> setInterval(int ms) async {
    _intervalMs = ms;
    await _bridge.setMonitorInterval(ms);
    if (_sub != null) {
      _stop();
      _start();
    }
  }

  /// One-shot reading for the home dashboard, without opening a stream.
  Future<MonitorSample?> snapshot() async {
    final raw = await _bridge.monitorSnapshot();
    if (raw.isEmpty) return null;
    final sample = MonitorSample.fromMap(raw);
    _latest = sample;
    notifyListeners();
    return sample;
  }

  Future<void> refreshServiceState() async {
    _serviceRunning = await _bridge.monitorServiceRunning();
    final overlay = await _bridge.overlayStatus();
    _overlayGranted = overlay['granted'] == true;
    _overlayRunning = overlay['running'] == true;
    notifyListeners();
  }

  /// FR-MON-7 — the persistent, notification-backed monitor.
  Future<void> startService() async {
    await _bridge.startMonitorService(_intervalMs);
    _serviceRunning = true;
    notifyListeners();
  }

  Future<void> stopService() async {
    await _bridge.stopMonitorService();
    _serviceRunning = false;
    if (_viewers == 0) _stop();
    notifyListeners();
  }

  // ---- FR-MON-6 overlay ---------------------------------------------------

  Future<void> requestOverlayPermission() async {
    await _bridge.requestOverlayPermission();
  }

  Future<String?> startOverlay() async {
    final r = await _bridge.startOverlay();
    await refreshServiceState();
    return r['ok'] == true ? null : (r['error'] as String? ?? 'Could not start the overlay');
  }

  Future<void> stopOverlay() async {
    await _bridge.stopOverlay();
    await refreshServiceState();
  }

  void clearHistory() {
    cpuHistory.clear();
    memoryHistory.clear();
    batteryTempHistory.clear();
    rxHistory.clear();
    txHistory.clear();
    notifyListeners();
  }

  /// NFR-PERF-2 — pause sampling while the app is not in the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    _bridge.setMonitorPaused(!foreground && !_serviceRunning);
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }
}
