import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// FR-SEN-1 — sensor metadata as reported by `android.hardware.Sensor`.
@immutable
class SensorInfo {
  const SensorInfo({
    required this.name,
    required this.vendor,
    required this.type,
    required this.typeName,
    required this.stringType,
    required this.version,
    required this.resolution,
    required this.maxRange,
    required this.power,
    required this.minDelay,
    required this.maxDelay,
    required this.reportingMode,
    required this.wakeUp,
    required this.dynamicSensor,
    required this.fifoMax,
    required this.valueCount,
    required this.unit,
    required this.axes,
    required this.selfTest,
  });

  factory SensorInfo.fromMap(Map<String, dynamic> m) => SensorInfo(
        name: m['name'] as String? ?? 'Unknown sensor',
        vendor: m['vendor'] as String? ?? '',
        type: (m['type'] as num?)?.toInt() ?? -1,
        typeName: m['typeName'] as String? ?? '',
        stringType: m['stringType'] as String? ?? '',
        version: (m['version'] as num?)?.toInt() ?? 0,
        resolution: (m['resolution'] as num?)?.toDouble() ?? 0,
        maxRange: (m['maxRange'] as num?)?.toDouble() ?? 0,
        power: (m['power'] as num?)?.toDouble() ?? 0,
        minDelay: (m['minDelay'] as num?)?.toInt() ?? 0,
        maxDelay: (m['maxDelay'] as num?)?.toInt() ?? 0,
        reportingMode: m['reportingMode'] as String? ?? '',
        wakeUp: m['wakeUp'] == true,
        dynamicSensor: m['dynamic'] == true,
        fifoMax: (m['fifoMax'] as num?)?.toInt() ?? 0,
        valueCount: (m['valueCount'] as num?)?.toInt() ?? 1,
        unit: m['unit'] as String? ?? '',
        axes: (m['axes'] as List?)?.map((e) => e.toString()).toList(growable: false) ??
            const ['value'],
        selfTest: m['selfTest'] is Map
            ? SensorSelfTest.fromMap(
                (m['selfTest'] as Map).map((k, v) => MapEntry(k.toString(), v)),
              )
            : null,
      );

  final String name;
  final String vendor;
  final int type;
  final String typeName;
  final String stringType;
  final int version;
  final double resolution;
  final double maxRange;
  final double power;
  final int minDelay;
  final int maxDelay;
  final String reportingMode;
  final bool wakeUp;
  final bool dynamicSensor;
  final int fifoMax;
  final int valueCount;
  final String unit;
  final List<String> axes;
  final SensorSelfTest? selfTest;

  /// FR-SEN-2 — one-shot and trigger sensors have no stream to graph.
  bool get streamable =>
      reportingMode == 'continuous' || reportingMode == 'on-change';

  double? get maxHz => minDelay > 0 ? 1000000 / minDelay : null;

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return name.toLowerCase().contains(q) ||
        typeName.toLowerCase().contains(q) ||
        vendor.toLowerCase().contains(q) ||
        stringType.toLowerCase().contains(q);
  }
}

/// FR-SEN-3 — how a self-test is presented and judged.
enum SelfTestMode {
  /// The reading must move around — accelerometer, gyroscope.
  variance,

  /// The reading must span a range — proximity covered/uncovered, light dark/bright.
  range,

  /// Any reading at all counts as a pass — pressure, humidity.
  present;

  static SelfTestMode parse(String? raw) => switch (raw) {
        'variance' => SelfTestMode.variance,
        'range' => SelfTestMode.range,
        _ => SelfTestMode.present,
      };
}

@immutable
class SensorSelfTest {
  const SensorSelfTest({
    required this.instruction,
    required this.mode,
    required this.threshold,
    required this.seconds,
  });

  factory SensorSelfTest.fromMap(Map<String, dynamic> m) => SensorSelfTest(
        instruction: m['instruction'] as String? ?? '',
        mode: SelfTestMode.parse(m['mode'] as String?),
        threshold: (m['threshold'] as num?)?.toDouble() ?? 0,
        seconds: (m['seconds'] as num?)?.toInt() ?? 6,
      );

  final String instruction;
  final SelfTestMode mode;
  final double threshold;
  final int seconds;
}

/// A live reading from the sensor event channel.
@immutable
class SensorReading {
  const SensorReading({required this.values, required this.accuracy, required this.at});

  factory SensorReading.fromMap(Map<String, dynamic> m) => SensorReading(
        values: (m['values'] as List?)?.map((e) => (e as num).toDouble()).toList(growable: false) ??
            const [],
        accuracy: (m['accuracy'] as num?)?.toInt() ?? -1,
        at: DateTime.now(),
      );

  final List<double> values;
  final int accuracy;
  final DateTime at;

  /// The single number the rolling graph plots: the raw value for one-axis sensors,
  /// the vector magnitude for three-axis ones.
  double get magnitude {
    if (values.isEmpty) return 0;
    if (values.length == 1) return values.first;
    var sum = 0.0;
    for (final v in values.take(3)) {
      sum += v * v;
    }
    return sum <= 0 ? 0 : math.sqrt(sum);
  }

  String get accuracyLabel => switch (accuracy) {
        0 => 'unreliable',
        1 => 'low',
        2 => 'medium',
        3 => 'high',
        _ => 'unknown',
      };
}
