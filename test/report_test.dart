import 'package:devaccess/core/models/info_field.dart';
import 'package:devaccess/core/util/formatters.dart';
import 'package:devaccess/core/util/report_builder.dart';
import 'package:flutter_test/flutter_test.dart';

const _appInfo = <String, dynamic>{
  'model': 'Google Pixel 8',
  'release': '14',
  'sdkInt': 34,
  'versionName': '1.0.0',
  'flavor': 'play',
};

final _sections = [
  InfoSection.fromMap({
    'id': 'device',
    'title': 'Device & Build',
    'live': false,
    'fields': [
      {'k': 'manufacturer', 'l': 'Manufacturer', 's': 'ok', 'v': 'Google'},
      {'k': 'model', 'l': 'Model', 's': 'ok', 'v': 'Pixel 8'},
      {'k': 'device', 'l': 'Device', 's': 'ok', 'v': 'shiba'},
      {'k': 'buildId', 'l': 'Build ID', 's': 'ok', 'v': 'UQ1A.240205.004'},
      {
        'k': 'fingerprint',
        'l': 'Fingerprint',
        's': 'ok',
        'v': 'google/shiba/shiba:14',
        'sensitive': true,
      },
      {'k': 'serial', 'l': 'Serial number', 's': 'restricted', 'r': 'Restricted from API 29'},
    ],
  }),
  InfoSection.fromMap({
    'id': 'os',
    'title': 'OS & Security',
    'live': false,
    'fields': [
      {'k': 'release', 'l': 'Android release', 's': 'ok', 'v': '14'},
      {'k': 'sdkInt', 'l': 'API level', 's': 'ok', 'v': 34},
      {'k': 'securityPatch', 'l': 'Security patch', 's': 'ok', 'v': '2024-02-05'},
      {'k': 'rootStatus', 'l': 'Root status', 's': 'ok', 'v': 'No root'},
    ],
  }),
];

void main() {
  group('ReportBuilder', () {
    test('FR-REP-2 — plain text carries every section', () {
      final text = ReportBuilder.build(
        format: ReportFormat.text,
        sections: _sections,
        appInfo: _appInfo,
      );
      expect(text, contains('DevAccess device report'));
      expect(text, contains('## Device & Build'));
      expect(text, contains('## OS & Security'));
      expect(text, contains('Pixel 8'));
    });

    test('FR-REP-2 — markdown escapes pipes so tables survive', () {
      final md = ReportBuilder.build(
        format: ReportFormat.markdown,
        sections: [
          InfoSection.fromMap({
            'id': 'x',
            'title': 'X',
            'fields': [
              {'k': 'a', 'l': 'Pipes', 's': 'ok', 'v': 'a|b'},
            ],
          }),
        ],
        appInfo: _appInfo,
      );
      expect(md, contains('# DevAccess device report'));
      expect(md, contains(r'a\|b'));
    });

    test('FR-REP-2 — JSON keeps the status and reason for restricted fields', () {
      final json = ReportBuilder.build(
        format: ReportFormat.json,
        sections: _sections,
        appInfo: _appInfo,
      );
      expect(json, contains('"report": "devaccess"'));
      expect(json, contains('"status": "restricted"'));
      expect(json, contains('Restricted from API 29'));
    });

    test('NFR-PRIV-2 — redaction masks the fingerprint and nothing else', () {
      final redacted = ReportBuilder.build(
        format: ReportFormat.text,
        sections: _sections,
        appInfo: _appInfo,
        redact: true,
      );
      expect(redacted, isNot(contains('google/shiba/shiba:14')));
      expect(redacted, contains('«redacted»'));
      expect(redacted, contains('Pixel 8'));
    });

    test('FR-REP-4 — the bug snippet is compact and ticket-ready', () {
      final snippet = ReportBuilder.bugSnippet(
        sections: _sections,
        appInfo: _appInfo,
        appUnderTest: 'com.example.app 2.1.0',
      );
      expect(snippet, contains('**Environment**'));
      expect(snippet, contains('Google Pixel 8'));
      expect(snippet, contains('API 34'));
      expect(snippet, contains('com.example.app 2.1.0'));
      expect(snippet.split('\n').length, lessThan(15));
    });

    test('a missing field degrades to an em dash rather than throwing', () {
      final snippet = ReportBuilder.bugSnippet(sections: const [], appInfo: const {});
      expect(snippet, contains(Fmt.dash));
    });
  });

  group('Fmt', () {
    test('binary and decimal byte units', () {
      expect(Fmt.bytes(1536, unit: ByteUnit.binary), '1.5 KiB');
      expect(Fmt.bytes(1500, unit: ByteUnit.decimal), '1.5 kB');
      expect(Fmt.bytes(null), Fmt.dash);
      expect(Fmt.bytes(-1), Fmt.dash);
    });

    test('temperature conversion', () {
      expect(Fmt.temperature(100, TemperatureUnit.celsius), '100.0 °C');
      expect(Fmt.temperature(100, TemperatureUnit.fahrenheit), '212.0 °F');
      expect(Fmt.temperature(null, TemperatureUnit.celsius), Fmt.dash);
    });

    test('frequency scales into MHz and GHz', () {
      expect(Fmt.frequency(1800000), '1.80 GHz');
      expect(Fmt.frequency(300000), '300 MHz');
      expect(Fmt.frequency(0), Fmt.dash);
    });

    test('durations and estimates', () {
      expect(Fmt.duration(const Duration(days: 2, hours: 3, minutes: 4)), '2d 3h 4m');
      expect(Fmt.minutes(-5), Fmt.dash);
      expect(Fmt.minutes(double.nan), Fmt.dash);
      expect(Fmt.minutes(90), '1h 30m');
    });

    test('timestamps are zero-padded', () {
      expect(Fmt.timestamp(DateTime(2024, 2, 5, 9, 7, 3)), '2024-02-05 09:07:03');
    });
  });
}
