import 'package:devaccess/core/models/info_field.dart';
import 'package:devaccess/core/models/monitor.dart';
import 'package:devaccess/core/models/sensor.dart';
import 'package:devaccess/core/models/tier.dart';
import 'package:devaccess/core/models/toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InfoField', () {
    test('parses an ok value', () {
      final f = InfoField.fromMap({'k': 'model', 'l': 'Model', 's': 'ok', 'v': 'Pixel 8'});
      expect(f.isOk, isTrue);
      expect(f.displayValue, 'Pixel 8');
    });

    test('FR-INFO-3 — a restricted field shows the reason, never a blank or a fake value', () {
      final f = InfoField.fromMap({
        'k': 'serial',
        'l': 'Serial number',
        's': 'restricted',
        'r': 'Restricted from API 29',
      });
      expect(f.isOk, isFalse);
      expect(f.displayValue, 'Restricted by OS');
      expect(f.reason, 'Restricted from API 29');
    });

    test('NFR-PRIV-2 — redaction masks sensitive fields and leaves the rest alone', () {
      final secret = InfoField.fromMap(
        {'k': 'fingerprint', 'l': 'Fingerprint', 's': 'ok', 'v': 'abc', 'sensitive': true},
      );
      final plain = InfoField.fromMap({'k': 'model', 'l': 'Model', 's': 'ok', 'v': 'Pixel'});
      expect(secret.redacted().displayValue, '«redacted»');
      expect(plain.redacted().displayValue, 'Pixel');
    });

    test('booleans and lists render readably', () {
      expect(
        InfoField.fromMap({'k': 'a', 'l': 'A', 's': 'ok', 'v': true}).displayValue,
        'Yes',
      );
      expect(
        InfoField.fromMap({'k': 'b', 'l': 'B', 's': 'ok', 'v': ['x', 'y']}).displayValue,
        'x, y',
      );
    });
  });

  group('InfoSection', () {
    final section = InfoSection.fromMap({
      'id': 'device',
      'title': 'Device & Build',
      'live': false,
      'fields': [
        {'k': 'model', 'l': 'Model', 's': 'ok', 'v': 'Pixel 8'},
        {'k': 'serial', 'l': 'Serial', 's': 'restricted', 'r': 'API 29+'},
      ],
    });

    test('counts restricted fields', () {
      expect(section.fields, hasLength(2));
      expect(section.restrictedCount, 1);
    });

    test('FR-INFO-2 — the whole section copies as an aligned text block', () {
      final text = section.asText();
      expect(text, contains('## Device & Build'));
      expect(text, contains('Pixel 8'));
      expect(text, contains('Restricted by OS'));
      expect(text, contains('API 29+'));
    });
  });

  group('AccessTier', () {
    test('maps levels and orders correctly', () {
      expect(AccessTier.fromLevel(2), AccessTier.t2);
      expect(AccessTier.fromLevel(99), AccessTier.t0);
      expect(AccessTier.t3.level > AccessTier.t2.level, isTrue);
    });

    test('root satisfies lower-tier scopes', () {
      const rooted = TierStatus(
        tier: AccessTier.t3,
        canWriteSystem: false,
        canWriteSecure: false,
        hasRoot: true,
        rootProbed: true,
        packageName: 'com.devaccess.app',
        adbCommand: '',
        adbDumpCommand: '',
        adbLogsCommand: '',
        wirelessDebuggingSupported: true,
        sdkInt: 34,
        flavor: 'foss',
        fullAccessBuild: true,
        suBinary: '/system/bin/su',
        magiskArtifacts: [],
        buildSignals: [],
        hasDump: false,
      );
      expect(rooted.canWriteScope('global'), isTrue);
      expect(rooted.canWriteScope('system'), isTrue);
      expect(rooted.allows(AccessTier.t2), isTrue);
    });
  });

  group('ToggleValue', () {
    const boolSpec = ToggleSpec(
      id: 'adb_enabled',
      label: 'USB debugging',
      scope: 'global',
      key: 'adb_enabled',
      type: 'int',
      kind: ToggleKind.boolean,
      requiredTier: AccessTier.t2,
      icon: Icons.usb,
    );

    test('reads an int flag as on/off', () {
      expect(const ToggleValue(spec: boolSpec, raw: '1').on, isTrue);
      expect(const ToggleValue(spec: boolSpec, raw: '0').on, isFalse);
    });

    test('an unset key reports the reason rather than pretending it is off', () {
      const v = ToggleValue(spec: boolSpec, reason: 'Key not set on this build');
      expect(v.isSet, isFalse);
      expect(v.display, 'Key not set on this build');
    });

    test('FR-TG-3 — a bitmask toggle uses its own on-value', () {
      const stayAwake = ToggleSpec(
        id: 'stay',
        label: 'Stay awake',
        scope: 'global',
        key: 'stay_on_while_plugged_in',
        type: 'int',
        kind: ToggleKind.boolean,
        requiredTier: AccessTier.t2,
        icon: Icons.bolt,
        onValue: '7',
      );
      expect(const ToggleValue(spec: stayAwake, raw: '7').on, isTrue);
      expect(const ToggleValue(spec: stayAwake, raw: '0').on, isFalse);
    });
  });

  group('WriteRecord', () {
    test('NFR-SEC-1 — round-trips through JSON for the audit log', () {
      final record = WriteRecord(
        toggleId: 'window_animation_scale',
        label: 'Window animation scale',
        scope: 'global',
        key: 'window_animation_scale',
        previous: '1.0',
        applied: '0.0',
        at: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        ok: true,
        method: 'content-provider',
      );
      final restored = WriteRecord.fromJson(record.toJson());
      expect(restored.toggleId, record.toggleId);
      expect(restored.previous, '1.0');
      expect(restored.at, record.at);
      expect(restored.undoable, isTrue);
    });

    test('FR-TG-8 — a failed write is not undoable', () {
      final failed = WriteRecord(
        toggleId: 'x',
        label: 'x',
        scope: 'global',
        key: 'x',
        previous: '1',
        applied: '0',
        at: DateTime.now(),
        ok: false,
        method: 'content-provider',
        error: 'rejected',
      );
      expect(failed.undoable, isFalse);
    });
  });

  group('MonitorSample', () {
    test('parses a full sample and derives memory pressure', () {
      final sample = MonitorSample.fromMap({
        'at': 1700000000000,
        'cpu': {
          'coreCount': 8,
          'totalLoad': 42.5,
          'loadReadable': true,
          'freqReadable': true,
          'cores': [
            {'index': 0, 'cur': 1800000, 'min': 300000, 'max': 2000000, 'load': 50.0},
          ],
        },
        'memory': {'total': 8000, 'available': 2000, 'used': 6000, 'lowMemory': false},
        'battery': {'level': 80, 'status': 'Discharging', 'temperature': 31.5},
        'thermal': {'statusLabel': 'None', 'zones': []},
        'network': {'supported': true, 'rxPerSec': 1024.0, 'txPerSec': 512.0},
      });
      expect(sample.coreCount, 8);
      expect(sample.cpuLoad, 42.5);
      expect(sample.memFraction, closeTo(0.75, 0.001));
      expect(sample.cores.single.frequencyFraction, closeTo(0.882, 0.01));
      expect(sample.batteryTempC, 31.5);
      expect(sample.rxPerSec, 1024.0);
    });

    test('NFR-RELIABILITY-1 — an empty payload yields a sample, not an exception', () {
      final sample = MonitorSample.fromMap(const {});
      expect(sample.coreCount, 0);
      expect(sample.cpuLoad, isNull);
      expect(sample.memFraction, 0);
      expect(sample.thermalZones, isEmpty);
    });
  });

  group('SensorInfo', () {
    test('parses metadata and the self-test hint', () {
      final sensor = SensorInfo.fromMap({
        'name': 'LSM6DSO Accelerometer',
        'vendor': 'ST',
        'type': 1,
        'typeName': 'Accelerometer',
        'reportingMode': 'continuous',
        'minDelay': 2000,
        'valueCount': 3,
        'unit': 'm/s²',
        'axes': ['X', 'Y', 'Z'],
        'selfTest': {
          'instruction': 'Move the device.',
          'mode': 'variance',
          'threshold': 0.5,
          'seconds': 6,
        },
      });
      expect(sensor.streamable, isTrue);
      expect(sensor.maxHz, closeTo(500, 0.1));
      expect(sensor.selfTest!.mode, SelfTestMode.variance);
    });

    test('FR-SEN-2 — one-shot sensors are not streamable', () {
      final trigger = SensorInfo.fromMap({
        'name': 'Significant motion',
        'type': 17,
        'reportingMode': 'one-shot',
      });
      expect(trigger.streamable, isFalse);
    });

    test('magnitude is the vector length for three-axis readings', () {
      final reading = SensorReading(values: const [3, 4, 0], accuracy: 3, at: DateTime.now());
      expect(reading.magnitude, closeTo(5, 0.0001));
    });
  });
}
