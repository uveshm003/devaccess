import 'package:flutter/foundation.dart';

/// Why a value is or is not present. Mirrors `com.devaccess.app.bridge.Field`.
enum FieldStatus {
  /// The read succeeded.
  ok,

  /// FR-INFO-3 — the OS forbids this read on this API level (C4/C5).
  restricted,

  /// The hardware does not exist, or the read failed.
  unavailable,

  /// A runtime permission the user has not granted yet.
  denied;

  static FieldStatus parse(Object? raw) => switch (raw) {
        'ok' => FieldStatus.ok,
        'restricted' => FieldStatus.restricted,
        'denied' => FieldStatus.denied,
        _ => FieldStatus.unavailable,
      };

  bool get isOk => this == FieldStatus.ok;
}

/// One row on the device-information dashboard (FR-INFO-2 — individually copyable).
@immutable
class InfoField {
  const InfoField({
    required this.key,
    required this.label,
    required this.status,
    this.value,
    this.reason,
    this.sensitive = false,
  });

  factory InfoField.fromMap(Map<String, dynamic> map) => InfoField(
        key: map['k'] as String? ?? '',
        label: map['l'] as String? ?? '',
        status: FieldStatus.parse(map['s']),
        value: map['v'],
        reason: map['r'] as String?,
        // NFR-PRIV-2 — identifiers are flagged so the redaction toggle can find them.
        sensitive: map['sensitive'] == true,
      );

  final String key;
  final String label;
  final FieldStatus status;
  final Object? value;
  final String? reason;
  final bool sensitive;

  bool get isOk => status.isOk;

  /// Text shown when the value is unavailable, per FR-INFO-3.
  String get placeholder => switch (status) {
        FieldStatus.restricted => 'Restricted by OS',
        FieldStatus.denied => 'Permission needed',
        FieldStatus.unavailable => 'Unavailable',
        FieldStatus.ok => '',
      };

  /// The plain string form used for copy, search and export.
  String get displayValue {
    if (!isOk) return placeholder;
    final v = value;
    if (v == null) return placeholder;
    if (v is bool) return v ? 'Yes' : 'No';
    if (v is List) return v.join(', ');
    return v.toString();
  }

  InfoField redacted() => sensitive && isOk
      ? InfoField(
          key: key,
          label: label,
          status: status,
          value: '«redacted»',
          reason: reason,
          sensitive: sensitive,
        )
      : this;
}

/// One collapsible group on the dashboard (FR-INFO-1).
@immutable
class InfoSection {
  const InfoSection({
    required this.id,
    required this.title,
    required this.live,
    required this.fields,
    this.error,
  });

  factory InfoSection.fromMap(Map<String, dynamic> map) => InfoSection(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        // FR-INFO-4 — live sections refresh while visible.
        live: map['live'] == true,
        fields: (map['fields'] as List?)
                ?.whereType<Map>()
                .map((e) => InfoField.fromMap(e.map((k, v) => MapEntry(k.toString(), v))))
                .toList(growable: false) ??
            const [],
        error: map['error'] as String?,
      );

  const InfoSection.placeholder(this.id, this.title, {this.live = false})
      : fields = const [],
        error = null;

  final String id;
  final String title;
  final bool live;
  final List<InfoField> fields;
  final String? error;

  bool get isLoaded => fields.isNotEmpty || error != null;

  int get restrictedCount => fields.where((f) => !f.isOk).length;

  InfoSection redacted() => InfoSection(
        id: id,
        title: title,
        live: live,
        fields: fields.map((f) => f.redacted()).toList(growable: false),
        error: error,
      );

  /// FR-INFO-2 — the whole section as one copyable block.
  String asText() {
    final width = fields.fold<int>(0, (m, f) => f.label.length > m ? f.label.length : m);
    final buffer = StringBuffer('## $title\n');
    if (error != null) buffer.writeln('  (section failed: $error)');
    for (final f in fields) {
      final value = f.displayValue.replaceAll('\n', '\n${' ' * (width + 4)}');
      buffer.writeln('  ${f.label.padRight(width)}  $value');
      if (!f.isOk && f.reason != null) {
        buffer.writeln('  ${' ' * width}  ↳ ${f.reason}');
      }
    }
    return buffer.toString();
  }
}
