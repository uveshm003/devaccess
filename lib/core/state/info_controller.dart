import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/info_field.dart';
import '../platform/channels.dart';

/// FR-INFO-1..4 — loads the dashboard sections and keeps the live ones fresh.
///
/// NFR-PERF-1 — sections load individually and in order, so the first card is on screen
/// while the GPU probe and camera enumeration are still running.
class InfoController extends ChangeNotifier {
  InfoController(this._bridge);

  final DevAccessBridge _bridge;

  final Map<String, InfoSection> _sections = {};
  List<String> _order = const [];
  bool _loadingIndex = false;
  final Set<String> _loading = {};
  Timer? _liveTimer;
  final Set<String> _visibleLive = {};

  List<InfoSection> get sections =>
      _order.map((id) => _sections[id]).whereType<InfoSection>().toList(growable: false);

  bool get loadingIndex => _loadingIndex;

  bool isLoading(String id) => _loading.contains(id);

  InfoSection? section(String id) => _sections[id];

  Future<void> loadIndex() async {
    if (_order.isNotEmpty) return;
    _loadingIndex = true;
    notifyListeners();
    final index = await _bridge.infoIndex();
    _order = index.map((e) => e['id'] as String).toList(growable: false);
    for (final e in index) {
      final id = e['id'] as String;
      _sections[id] = InfoSection.placeholder(
        id,
        e['title'] as String? ?? id,
        live: e['live'] == true,
      );
    }
    _loadingIndex = false;
    notifyListeners();
  }

  /// Loads one section, unless it is already loaded and [force] is false.
  Future<void> loadSection(String id, {bool force = false}) async {
    final existing = _sections[id];
    if (!force && existing != null && existing.isLoaded) return;
    if (_loading.contains(id)) return;
    _loading.add(id);
    notifyListeners();
    final raw = await _bridge.infoSection(id);
    if (raw.isNotEmpty) _sections[id] = InfoSection.fromMap(raw);
    _loading.remove(id);
    notifyListeners();
  }

  /// NFR-PERF-1 — walks the sections in order so the cheap ones paint first.
  Future<void> loadAllProgressively() async {
    await loadIndex();
    for (final id in _order) {
      await loadSection(id);
    }
  }

  /// FR-INFO-4 — a live section refreshes only while it is on screen.
  void setSectionVisible(String id, bool visible) {
    final section = _sections[id];
    if (section == null || !section.live) return;
    if (visible) {
      _visibleLive.add(id);
    } else {
      _visibleLive.remove(id);
    }
    _syncLiveTimer();
  }

  int _refreshMs = 2000;

  set refreshInterval(int ms) {
    _refreshMs = ms;
    if (_liveTimer != null) {
      _liveTimer!.cancel();
      _liveTimer = null;
      _syncLiveTimer();
    }
  }

  void _syncLiveTimer() {
    if (_visibleLive.isEmpty) {
      _liveTimer?.cancel();
      _liveTimer = null;
      return;
    }
    _liveTimer ??= Timer.periodic(Duration(milliseconds: _refreshMs), (_) async {
      for (final id in _visibleLive.toList()) {
        await loadSection(id, force: true);
      }
    });
  }

  void stopLiveRefresh() {
    _visibleLive.clear();
    _liveTimer?.cancel();
    _liveTimer = null;
  }

  /// FR-INFO-2 / FR-REP-1 — every loaded section, optionally with identifiers masked.
  List<InfoSection> snapshot({bool redact = false}) {
    final list = sections.where((s) => s.isLoaded).toList(growable: false);
    return redact ? list.map((s) => s.redacted()).toList(growable: false) : list;
  }

  /// FR-INFO-1 — search across every loaded field.
  List<({InfoSection section, InfoField field})> search(String query) {
    if (query.trim().isEmpty) return const [];
    final q = query.toLowerCase();
    final out = <({InfoSection section, InfoField field})>[];
    for (final s in sections) {
      for (final f in s.fields) {
        if (f.label.toLowerCase().contains(q) ||
            f.key.toLowerCase().contains(q) ||
            f.displayValue.toLowerCase().contains(q)) {
          out.add((section: s, field: f));
        }
      }
    }
    return out;
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }
}
