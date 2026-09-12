import 'dart:convert';

import '../models/info_field.dart';
import 'formatters.dart';

/// FR-REP-2 — the export formats.
enum ReportFormat {
  text('Plain text', 'txt', 'text/plain'),
  markdown('Markdown', 'md', 'text/markdown'),
  json('JSON', 'json', 'application/json'),
  pdf('PDF', 'pdf', 'application/pdf');

  const ReportFormat(this.label, this.extension, this.mime);

  final String label;
  final String extension;
  final String mime;
}

/// FR-REP-1..4 — turns the loaded dashboard into a shareable document.
///
/// NFR-PRIV-2 — [redact] masks every field the native layer flagged as an identifier
/// (fingerprint, serial, IP addresses, SSID/BSSID, MCC/MNC) before anything leaves the app.
abstract final class ReportBuilder {
  static String header(Map<String, dynamic> appInfo, {DateTime? at}) {
    final now = at ?? DateTime.now();
    return 'DevAccess device report\n'
        'Generated  ${Fmt.timestamp(now)}\n'
        'Device     ${appInfo['model'] ?? Fmt.dash}\n'
        'Android    ${appInfo['release'] ?? Fmt.dash} (API ${appInfo['sdkInt'] ?? Fmt.dash})\n'
        'DevAccess  ${appInfo['versionName'] ?? Fmt.dash} '
        '(${appInfo['flavor'] ?? Fmt.dash} flavour)\n';
  }

  static String build({
    required ReportFormat format,
    required List<InfoSection> sections,
    required Map<String, dynamic> appInfo,
    bool redact = false,
    DateTime? at,
  }) {
    final data = redact
        ? sections.map((s) => s.redacted()).toList(growable: false)
        : sections;
    return switch (format) {
      ReportFormat.json => _json(data, appInfo, redact, at),
      ReportFormat.markdown => _markdown(data, appInfo, redact, at),
      // The PDF renderer takes the plain-text body and lays it out natively.
      ReportFormat.text || ReportFormat.pdf => _text(data, appInfo, redact, at),
    };
  }

  static String _text(
    List<InfoSection> sections,
    Map<String, dynamic> appInfo,
    bool redact,
    DateTime? at,
  ) {
    final b = StringBuffer(header(appInfo, at: at));
    if (redact) b.writeln('Identifiers redacted for sharing.');
    b.writeln('${'=' * 64}\n');
    for (final s in sections) {
      b.writeln(s.asText());
    }
    return b.toString();
  }

  static String _markdown(
    List<InfoSection> sections,
    Map<String, dynamic> appInfo,
    bool redact,
    DateTime? at,
  ) {
    final now = at ?? DateTime.now();
    final b = StringBuffer('# DevAccess device report\n\n');
    b.writeln('| | |');
    b.writeln('|---|---|');
    b.writeln('| Generated | ${Fmt.timestamp(now)} |');
    b.writeln('| Device | ${appInfo['model'] ?? Fmt.dash} |');
    b.writeln('| Android | ${appInfo['release'] ?? Fmt.dash} (API ${appInfo['sdkInt'] ?? Fmt.dash}) |');
    b.writeln('| DevAccess | ${appInfo['versionName'] ?? Fmt.dash} (${appInfo['flavor'] ?? Fmt.dash}) |');
    if (redact) b.writeln('| Redaction | identifiers masked |');
    b.writeln();

    for (final s in sections) {
      b.writeln('## ${s.title}\n');
      if (s.error != null) b.writeln('> Section failed: ${s.error}\n');
      b.writeln('| Field | Value |');
      b.writeln('|---|---|');
      for (final f in s.fields) {
        final value = f.isOk
            ? _escapeCell(f.displayValue)
            : '_${f.placeholder}_${f.reason == null ? '' : ' — ${_escapeCell(f.reason!)}'}';
        b.writeln('| ${_escapeCell(f.label)} | $value |');
      }
      b.writeln();
    }
    return b.toString();
  }

  static String _escapeCell(String v) => v.replaceAll('|', r'\|').replaceAll('\n', '<br>');

  static String _json(
    List<InfoSection> sections,
    Map<String, dynamic> appInfo,
    bool redact,
    DateTime? at,
  ) {
    final doc = {
      'report': 'devaccess',
      'generatedAt': (at ?? DateTime.now()).toIso8601String(),
      'redacted': redact,
      'app': appInfo,
      'sections': [
        for (final s in sections)
          {
            'id': s.id,
            'title': s.title,
            if (s.error != null) 'error': s.error,
            'fields': [
              for (final f in s.fields)
                {
                  'key': f.key,
                  'label': f.label,
                  'status': f.status.name,
                  'value': f.isOk ? f.value : null,
                  if (f.reason != null) 'reason': f.reason,
                  if (f.sensitive) 'sensitive': true,
                },
            ],
          },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(doc);
  }

  /// FR-REP-4 — the compact, ticket-ready block.
  static String bugSnippet({
    required List<InfoSection> sections,
    required Map<String, dynamic> appInfo,
    String? appUnderTest,
    bool redact = false,
    DateTime? at,
  }) {
    String find(String sectionId, String key) {
      final section = sections.where((s) => s.id == sectionId).firstOrNull;
      final field = section?.fields.where((f) => f.key == key).firstOrNull;
      if (field == null) return Fmt.dash;
      return (redact ? field.redacted() : field).displayValue;
    }

    final now = at ?? DateTime.now();
    return '''
**Environment**
- Device: ${find('device', 'manufacturer')} ${find('device', 'model')} (${find('device', 'device')})
- Android: ${find('os', 'release')} · API ${find('os', 'sdkInt')} · patch ${find('os', 'securityPatch')}
- Build: ${find('device', 'buildId')} / ${find('device', 'incremental')}
- SoC: ${find('cpu', 'socName')} · ${find('cpu', 'coreCount')} cores · ${find('cpu', 'arch')}
- RAM: ${find('memory', 'total')} total, ${find('memory', 'available')} free
- Display: ${find('display', 'resolution')} @ ${find('display', 'densityDpi')} · ${find('display', 'refreshRate')}
- Locale: ${find('system', 'locale')} · TZ ${find('system', 'timezone')}
- Root: ${find('os', 'rootStatus')} · Emulator: ${find('device', 'emulator')}
${appUnderTest == null || appUnderTest.isEmpty ? '' : '- App under test: $appUnderTest\n'}- Captured: ${Fmt.timestamp(now)}
''';
  }
}
