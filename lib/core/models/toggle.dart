import 'package:flutter/material.dart';

import 'tier.dart';

/// The shape of the control a toggle renders as.
enum ToggleKind {
  /// On/off, stored as an int (0/1) or a bitmask.
  boolean,

  /// A small set of named values — animation scales, background process limit.
  choice,

  /// A continuous integer range — brightness, screen timeout.
  slider,

  /// FR-TG-7 — no writable key exists; DevAccess reads the value and deep-links only.
  readOnly,

  /// Not a Settings key at all — demo mode, "kill all animations".
  action,
}

/// A named preset offered for a [ToggleKind.choice] control.
@immutable
class TogglePreset {
  const TogglePreset(this.label, this.value);

  final String label;
  final String value;
}

/// FR-TG-1..8 — one developer/system setting DevAccess can read and, at the right tier, write.
@immutable
class ToggleSpec {
  const ToggleSpec({
    required this.id,
    required this.label,
    required this.scope,
    required this.key,
    required this.type,
    required this.kind,
    required this.requiredTier,
    required this.icon,
    this.description,
    this.presets = const [],
    this.min = 0,
    this.max = 100,
    this.onValue = '1',
    this.offValue = '0',
    this.launcherId,
    this.note,
    this.synonyms = const [],
    this.minSdk,
  });

  final String id;
  final String label;
  final String? description;

  /// `system`, `secure` or `global`.
  final String scope;
  final String key;

  /// `int`, `long`, `float` or `string`.
  final String type;
  final ToggleKind kind;

  /// The tier needed to *write* this. Every toggle reads at T0.
  final AccessTier requiredTier;
  final IconData icon;
  final List<TogglePreset> presets;
  final int min;
  final int max;
  final String onValue;
  final String offValue;

  /// FR-TG-7 — where to deep-link when the value is not writable here.
  final String? launcherId;

  /// Extra caveat shown under the control.
  final String? note;
  final List<String> synonyms;
  final int? minSdk;

  bool get writable => kind != ToggleKind.readOnly;

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return label.toLowerCase().contains(q) ||
        key.toLowerCase().contains(q) ||
        (description?.toLowerCase().contains(q) ?? false) ||
        synonyms.any((s) => s.toLowerCase().contains(q));
  }

  /// Interprets a raw settings value as on/off for [ToggleKind.boolean].
  bool isOn(String? raw) {
    if (raw == null) return false;
    if (onValue == '1') return (int.tryParse(raw.trim()) ?? 0) != 0;
    return raw.trim() == onValue;
  }
}

/// The live read-back of a toggle (FR-TG-8 — always the real value, never an assumption).
@immutable
class ToggleValue {
  const ToggleValue({required this.spec, this.raw, this.reason});

  final ToggleSpec spec;
  final String? raw;
  final String? reason;

  bool get isSet => raw != null;

  bool get on => spec.isOn(raw);

  double? get asDouble => raw == null ? null : double.tryParse(raw!.trim());

  int? get asInt => raw == null ? null : int.tryParse(raw!.trim());

  String get display {
    if (raw == null) return reason ?? 'Not set on this build';
    if (spec.kind == ToggleKind.boolean) return on ? 'On' : 'Off';
    for (final p in spec.presets) {
      if (p.value == raw) return p.label;
    }
    return raw!;
  }

  ToggleValue copyWith({String? raw, String? reason}) =>
      ToggleValue(spec: spec, raw: raw ?? this.raw, reason: reason ?? this.reason);
}

/// NFR-SEC-1 — one entry in the local audit log of elevated writes.
@immutable
class WriteRecord {
  const WriteRecord({
    required this.toggleId,
    required this.label,
    required this.scope,
    required this.key,
    required this.previous,
    required this.applied,
    required this.at,
    required this.ok,
    required this.method,
    this.error,
  });

  factory WriteRecord.fromJson(Map<String, dynamic> j) => WriteRecord(
        toggleId: j['toggleId'] as String? ?? '',
        label: j['label'] as String? ?? '',
        scope: j['scope'] as String? ?? '',
        key: j['key'] as String? ?? '',
        previous: j['previous'] as String?,
        applied: j['applied'] as String? ?? '',
        at: DateTime.fromMillisecondsSinceEpoch((j['at'] as num?)?.toInt() ?? 0),
        ok: j['ok'] == true,
        method: j['method'] as String? ?? '',
        error: j['error'] as String?,
      );

  final String toggleId;
  final String label;
  final String scope;
  final String key;
  final String? previous;
  final String applied;
  final DateTime at;
  final bool ok;
  final String method;
  final String? error;

  /// FR-TG-8 — an undo is only offered when the previous value is known.
  bool get undoable => ok && previous != null;

  Map<String, dynamic> toJson() => {
        'toggleId': toggleId,
        'label': label,
        'scope': scope,
        'key': key,
        'previous': previous,
        'applied': applied,
        'at': at.millisecondsSinceEpoch,
        'ok': ok,
        'method': method,
        'error': error,
      };
}
