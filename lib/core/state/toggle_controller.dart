import 'package:flutter/foundation.dart';

import '../../data/toggle_catalog.dart';
import '../models/tier.dart';
import '../models/toggle.dart';
import '../platform/channels.dart';
import 'app_settings.dart';
import 'tier_controller.dart';

/// The outcome of a write attempt, always reflecting the *re-read* value (FR-TG-8).
@immutable
class WriteOutcome {
  const WriteOutcome({
    required this.ok,
    required this.actual,
    required this.previous,
    required this.method,
    this.error,
  });

  final bool ok;
  final String? actual;
  final String? previous;
  final String method;
  final String? error;
}

/// FR-TG-1..8 — reads every toggle at T0 and writes the ones the current tier allows.
class ToggleController extends ChangeNotifier {
  ToggleController(this._bridge, this._tier, this._settings);

  final DevAccessBridge _bridge;
  final TierController _tier;
  final AppSettings _settings;

  final Map<String, ToggleValue> _values = {};
  bool _loading = false;
  WriteRecord? _lastWrite;

  bool get loading => _loading;

  /// FR-TG-8 — the write that the undo affordance refers to.
  WriteRecord? get lastWrite => _lastWrite;

  ToggleValue? value(String id) => _values[id];

  Future<void> refreshAll() async {
    _loading = true;
    notifyListeners();

    final settingsToggles =
        ToggleCatalog.all.where((t) => t.scope != 'prop').toList(growable: false);
    final results = await _bridge.readSettings(
      settingsToggles.map((t) => {'scope': t.scope, 'key': t.key}).toList(growable: false),
    );

    for (var i = 0; i < settingsToggles.length; i++) {
      final spec = settingsToggles[i];
      final raw = i < results.length ? results[i] : const <String, dynamic>{};
      _values[spec.id] = ToggleValue(
        spec: spec,
        raw: raw['s'] == 'ok' ? raw['v']?.toString() : null,
        reason: raw['r'] as String?,
      );
    }

    // `prop` toggles are SystemProperties, not Settings keys; they have no cheap read
    // path for an unprivileged app, so they are shown as "unknown until root".
    for (final spec in ToggleCatalog.all.where((t) => t.scope == 'prop')) {
      _values[spec.id] = ToggleValue(
        spec: spec,
        raw: null,
        reason: 'SystemProperties values are not readable without root (T3)',
      );
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> refreshOne(String id) async {
    final spec = ToggleCatalog.byId(id);
    if (spec == null || spec.scope == 'prop') return;
    final raw = await _bridge.readSetting(spec.scope, spec.key);
    _values[id] = ToggleValue(
      spec: spec,
      raw: raw['s'] == 'ok' ? raw['v']?.toString() : null,
      reason: raw['r'] as String?,
    );
    notifyListeners();
  }

  /// True when the current tier can write [spec] (FR-TIER-3 drives the locked badge).
  bool canWrite(ToggleSpec spec) {
    if (spec.kind == ToggleKind.readOnly) return false;
    final status = _tier.status;
    if (status.hasRoot) return true;
    return status.tier.level >= spec.requiredTier.level;
  }

  /// Writes [value] and returns the verified outcome. Never assumes success.
  Future<WriteOutcome> write(ToggleSpec spec, String value) async {
    if (!canWrite(spec)) {
      return WriteOutcome(
        ok: false,
        actual: _values[spec.id]?.raw,
        previous: _values[spec.id]?.raw,
        method: 'none',
        error: 'Tier ${spec.requiredTier.code} is required; DevAccess currently has '
            '${_tier.tier.code}.',
      );
    }

    final Map<String, dynamic> result;
    if (spec.scope == 'prop') {
      final r = await _bridge.setProp(spec.key, value);
      result = {
        'ok': r['ok'],
        'actual': r['ok'] == true ? value : null,
        'previous': _values[spec.id]?.raw,
        'method': 'su setprop',
        'error': r['error'],
      };
    } else {
      result = await _bridge.writeSetting(
        scope: spec.scope,
        key: spec.key,
        value: value,
        type: spec.type,
      );
    }

    final outcome = WriteOutcome(
      ok: result['ok'] == true,
      actual: result['actual'] as String?,
      previous: result['previous'] as String?,
      method: result['method'] as String? ?? 'unknown',
      error: result['error'] as String?,
    );

    // FR-TG-8 — reflect the value the OS actually reports back.
    _values[spec.id] = ToggleValue(
      spec: spec,
      raw: outcome.actual ?? (outcome.ok ? value : _values[spec.id]?.raw),
      reason: _values[spec.id]?.reason,
    );

    final record = WriteRecord(
      toggleId: spec.id,
      label: spec.label,
      scope: spec.scope,
      key: spec.key,
      previous: outcome.previous,
      applied: value,
      at: DateTime.now(),
      ok: outcome.ok,
      method: outcome.method,
      error: outcome.error,
    );
    _lastWrite = record;
    // NFR-SEC-1 — every elevated write is logged locally so the user can review it.
    await _settings.recordWrite(record);
    notifyListeners();
    return outcome;
  }

  /// FR-TG-8 — puts the previous value back.
  Future<WriteOutcome?> undo(WriteRecord record) async {
    final spec = ToggleCatalog.byId(record.toggleId);
    final previous = record.previous;
    if (spec == null || previous == null) return null;
    return write(spec, previous);
  }

  /// FR-TG-1 — the one-tap "kill all animations" (and its restore).
  Future<List<WriteOutcome>> setAllAnimationScales(String value) async {
    final outcomes = <WriteOutcome>[];
    for (final spec in ToggleCatalog.animationScales) {
      outcomes.add(await write(spec, value));
    }
    return outcomes;
  }

  bool get animationsOff => ToggleCatalog.animationScales.every((spec) {
        final v = _values[spec.id]?.asDouble;
        return v != null && v == 0;
      });

  /// FR-TG-5 — SystemUI demo mode with a clean status bar for screenshots.
  Future<String?> setDemoMode(bool enabled) async {
    if (!_tier.status.canWriteSecure && !_tier.status.hasRoot) {
      return 'Demo mode needs tier ${AccessTier.t2.code}.';
    }
    final r = await _bridge.setDemoMode(
      enabled,
      enabled
          ? const {'command': 'battery', 'level': '100', 'plugged': 'false'}
          : null,
    );
    return r['ok'] == true ? null : (r['error'] as String? ?? 'Demo mode command was rejected');
  }

  List<ToggleSpec> search(String query) =>
      ToggleCatalog.all.where((t) => t.matches(query)).toList(growable: false);
}
