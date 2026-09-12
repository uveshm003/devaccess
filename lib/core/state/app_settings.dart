import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/toggle.dart';
import '../theme/app_theme.dart';
import '../platform/channels.dart';
import '../util/formatters.dart';

/// FR-SET-1..3 — every user preference, persisted as one JSON blob through the bridge.
///
/// Keeping the whole schema on the Dart side makes backup/restore (FR-SET-3) a single
/// string round-trip and keeps the native layer free of product concepts.
class AppSettings extends ChangeNotifier {
  AppSettings(this._bridge);

  final DevAccessBridge _bridge;

  static const int schemaVersion = 1;

  ThemeMode _themeMode = ThemeMode.system;
  bool _dynamicColour = true;
  Color _accent = AppTheme.brandSeed;
  ByteUnit _byteUnit = ByteUnit.binary;
  TemperatureUnit _temperatureUnit = TemperatureUnit.celsius;
  int _samplingIntervalMs = 1000;
  int _infoRefreshMs = 2000;
  bool _redactByDefault = false;
  bool _probeRootOnStart = false;
  bool _confirmElevatedWrites = true;
  List<String> _favouriteLaunchers = const [];
  List<String> _favouriteToggles = const [];
  List<String> _dashboardSections = const ['device', 'os', 'battery', 'memory', 'cpu', 'network'];
  List<WriteRecord> _auditLog = const [];
  bool _loaded = false;

  bool get loaded => _loaded;

  ThemeMode get themeMode => _themeMode;

  bool get dynamicColour => _dynamicColour;

  Color get accent => _accent;

  ByteUnit get byteUnit => _byteUnit;

  TemperatureUnit get temperatureUnit => _temperatureUnit;

  /// FR-MON-7 / FR-INFO-4 — configurable sampling rate.
  int get samplingIntervalMs => _samplingIntervalMs;

  int get infoRefreshMs => _infoRefreshMs;

  /// NFR-PRIV-2 — start every share with identifiers masked.
  bool get redactByDefault => _redactByDefault;

  /// Probing root spawns `su`, which can raise a Magisk prompt — opt-in only.
  bool get probeRootOnStart => _probeRootOnStart;

  /// NFR-SEC-1 — elevated writes ask first.
  bool get confirmElevatedWrites => _confirmElevatedWrites;

  List<String> get favouriteLaunchers => _favouriteLaunchers;

  List<String> get favouriteToggles => _favouriteToggles;

  List<String> get dashboardSections => _dashboardSections;

  /// NFR-SEC-1 — the local, reviewable record of every elevated write.
  List<WriteRecord> get auditLog => _auditLog;

  Future<void> load() async {
    final raw = await _bridge.loadPrefs();
    if (raw != null && raw.isNotEmpty) {
      try {
        _apply(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // A corrupt blob must not stop the app from starting; defaults win.
      }
    }
    _loaded = true;
    notifyListeners();
  }

  void _apply(Map<String, dynamic> j) {
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == j['themeMode'],
      orElse: () => ThemeMode.system,
    );
    _dynamicColour = j['dynamicColour'] as bool? ?? true;
    _accent = Color((j['accent'] as num?)?.toInt() ?? AppTheme.brandSeed.toARGB32());
    _byteUnit = ByteUnit.values.firstWhere(
      (u) => u.name == j['byteUnit'],
      orElse: () => ByteUnit.binary,
    );
    _temperatureUnit = TemperatureUnit.values.firstWhere(
      (u) => u.name == j['temperatureUnit'],
      orElse: () => TemperatureUnit.celsius,
    );
    _samplingIntervalMs = (j['samplingIntervalMs'] as num?)?.toInt() ?? 1000;
    _infoRefreshMs = (j['infoRefreshMs'] as num?)?.toInt() ?? 2000;
    _redactByDefault = j['redactByDefault'] as bool? ?? false;
    _probeRootOnStart = j['probeRootOnStart'] as bool? ?? false;
    _confirmElevatedWrites = j['confirmElevatedWrites'] as bool? ?? true;
    _favouriteLaunchers = _stringList(j['favouriteLaunchers']);
    _favouriteToggles = _stringList(j['favouriteToggles']);
    final sections = _stringList(j['dashboardSections']);
    if (sections.isNotEmpty) _dashboardSections = sections;
    _auditLog = (j['auditLog'] as List?)
            ?.whereType<Map>()
            .map((e) => WriteRecord.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
            .toList(growable: false) ??
        const [];
  }

  static List<String> _stringList(Object? raw) =>
      (raw as List?)?.map((e) => e.toString()).toList(growable: false) ?? const [];

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'themeMode': _themeMode.name,
        'dynamicColour': _dynamicColour,
        'accent': _accent.toARGB32(),
        'byteUnit': _byteUnit.name,
        'temperatureUnit': _temperatureUnit.name,
        'samplingIntervalMs': _samplingIntervalMs,
        'infoRefreshMs': _infoRefreshMs,
        'redactByDefault': _redactByDefault,
        'probeRootOnStart': _probeRootOnStart,
        'confirmElevatedWrites': _confirmElevatedWrites,
        'favouriteLaunchers': _favouriteLaunchers,
        'favouriteToggles': _favouriteToggles,
        'dashboardSections': _dashboardSections,
        'auditLog': _auditLog.map((e) => e.toJson()).toList(growable: false),
      };

  Future<void> _persist() async {
    notifyListeners();
    await _bridge.savePrefs(jsonEncode(toJson()));
  }

  // ---- mutators -----------------------------------------------------------

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _persist();
  }

  Future<void> setDynamicColour(bool value) async {
    _dynamicColour = value;
    await _persist();
  }

  Future<void> setAccent(Color colour) async {
    _accent = colour;
    await _persist();
  }

  Future<void> setByteUnit(ByteUnit unit) async {
    _byteUnit = unit;
    await _persist();
  }

  Future<void> setTemperatureUnit(TemperatureUnit unit) async {
    _temperatureUnit = unit;
    await _persist();
  }

  Future<void> setSamplingInterval(int ms) async {
    _samplingIntervalMs = ms.clamp(250, 10000);
    await _bridge.setMonitorInterval(_samplingIntervalMs);
    await _persist();
  }

  Future<void> setInfoRefresh(int ms) async {
    _infoRefreshMs = ms.clamp(500, 30000);
    await _persist();
  }

  Future<void> setRedactByDefault(bool value) async {
    _redactByDefault = value;
    await _persist();
  }

  Future<void> setProbeRootOnStart(bool value) async {
    _probeRootOnStart = value;
    await _persist();
  }

  Future<void> setConfirmElevatedWrites(bool value) async {
    _confirmElevatedWrites = value;
    await _persist();
  }

  bool isFavouriteLauncher(String id) => _favouriteLaunchers.contains(id);

  bool isFavouriteToggle(String id) => _favouriteToggles.contains(id);

  /// FR-QA-5 — pinning, which also drives the launcher shortcuts (FR-SURF-3).
  Future<void> toggleFavouriteLauncher(String id) async {
    _favouriteLaunchers = _favouriteLaunchers.contains(id)
        ? (_favouriteLaunchers.toList()..remove(id))
        : [..._favouriteLaunchers, id];
    await _persist();
  }

  Future<void> toggleFavouriteToggle(String id) async {
    _favouriteToggles = _favouriteToggles.contains(id)
        ? (_favouriteToggles.toList()..remove(id))
        : [..._favouriteToggles, id];
    await _persist();
  }

  Future<void> setDashboardSections(List<String> ids) async {
    _dashboardSections = ids;
    await _persist();
  }

  Future<void> recordWrite(WriteRecord record) async {
    // Keep the log bounded; the newest 100 entries are what a user ever reviews.
    _auditLog = [record, ..._auditLog].take(100).toList(growable: false);
    await _persist();
  }

  Future<void> clearAuditLog() async {
    _auditLog = const [];
    await _persist();
  }

  /// FR-SET-3 — the export half of backup/restore.
  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// FR-SET-3 — the restore half. Returns null on success, or a message on failure.
  Future<String?> importJson(String raw) async {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return 'That file is not a DevAccess backup.';
      if (decoded['schemaVersion'] is! num) {
        return 'That file has no schemaVersion — it is not a DevAccess backup.';
      }
      _apply(decoded);
      await _persist();
      return null;
    } catch (e) {
      return 'Could not read that backup: $e';
    }
  }

  Future<void> resetAll() async {
    _themeMode = ThemeMode.system;
    _dynamicColour = true;
    _accent = AppTheme.brandSeed;
    _byteUnit = ByteUnit.binary;
    _temperatureUnit = TemperatureUnit.celsius;
    _samplingIntervalMs = 1000;
    _infoRefreshMs = 2000;
    _redactByDefault = false;
    _probeRootOnStart = false;
    _confirmElevatedWrites = true;
    _favouriteLaunchers = const [];
    _favouriteToggles = const [];
    _dashboardSections = const ['device', 'os', 'battery', 'memory', 'cpu', 'network'];
    _auditLog = const [];
    await _persist();
  }
}
