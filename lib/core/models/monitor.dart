import 'package:flutter/foundation.dart';

/// FR-MON-1 — one CPU core in a sample.
@immutable
class CoreSample {
  const CoreSample({
    required this.index,
    this.currentKHz,
    this.minKHz,
    this.maxKHz,
    this.governor,
    this.online = true,
    this.load,
  });

  factory CoreSample.fromMap(Map<String, dynamic> m) => CoreSample(
        index: (m['index'] as num?)?.toInt() ?? 0,
        currentKHz: (m['cur'] as num?)?.toInt(),
        minKHz: (m['min'] as num?)?.toInt(),
        maxKHz: (m['max'] as num?)?.toInt(),
        governor: m['governor'] as String?,
        online: m['online'] != false,
        load: (m['load'] as num?)?.toDouble(),
      );

  final int index;
  final int? currentKHz;
  final int? minKHz;
  final int? maxKHz;
  final String? governor;
  final bool online;
  final double? load;

  double? get ghz => currentKHz == null ? null : currentKHz! / 1000000;

  /// How far up its own frequency range this core is running.
  double? get frequencyFraction {
    final cur = currentKHz, lo = minKHz, hi = maxKHz;
    if (cur == null || lo == null || hi == null || hi <= lo) return null;
    return ((cur - lo) / (hi - lo)).clamp(0.0, 1.0);
  }
}

/// FR-MON-1..5 — a single pass of the sampling loop.
@immutable
class MonitorSample {
  const MonitorSample({
    required this.at,
    required this.cores,
    required this.cpuLoad,
    required this.coreCount,
    required this.governor,
    required this.cpuLoadReadable,
    required this.cpuFreqReadable,
    required this.memTotal,
    required this.memAvailable,
    required this.memUsed,
    required this.memThreshold,
    required this.lowMemory,
    required this.selfPssBytes,
    required this.batteryLevel,
    required this.batteryStatus,
    required this.charging,
    required this.batteryTempC,
    required this.batteryVoltage,
    required this.batteryCurrentMa,
    required this.batteryPlugged,
    required this.batteryHealth,
    required this.batteryRatePerHour,
    required this.batteryEstimateMinutes,
    required this.thermalStatus,
    required this.thermalZones,
    required this.thermalReason,
    required this.rxPerSec,
    required this.txPerSec,
    required this.uidRxPerSec,
    required this.uidTxPerSec,
    required this.throughputSupported,
  });

  factory MonitorSample.fromMap(Map<String, dynamic> m) {
    Map<String, dynamic> sub(String key) {
      final v = m[key];
      if (v is Map) return v.map((k, x) => MapEntry(k.toString(), x));
      return const {};
    }

    final cpu = sub('cpu');
    final mem = sub('memory');
    final batt = sub('battery');
    final therm = sub('thermal');
    final net = sub('network');

    return MonitorSample(
      at: DateTime.fromMillisecondsSinceEpoch((m['at'] as num?)?.toInt() ?? 0),
      cores: (cpu['cores'] as List?)
              ?.whereType<Map>()
              .map((e) => CoreSample.fromMap(e.map((k, v) => MapEntry(k.toString(), v))))
              .toList(growable: false) ??
          const [],
      cpuLoad: (cpu['totalLoad'] as num?)?.toDouble(),
      coreCount: (cpu['coreCount'] as num?)?.toInt() ?? 0,
      governor: cpu['governor'] as String?,
      cpuLoadReadable: cpu['loadReadable'] == true,
      cpuFreqReadable: cpu['freqReadable'] == true,
      memTotal: (mem['total'] as num?)?.toInt() ?? 0,
      memAvailable: (mem['available'] as num?)?.toInt() ?? 0,
      memUsed: (mem['used'] as num?)?.toInt() ?? 0,
      memThreshold: (mem['threshold'] as num?)?.toInt() ?? 0,
      lowMemory: mem['lowMemory'] == true,
      selfPssBytes: ((mem['selfPssKb'] as num?)?.toInt() ?? -1) * 1024,
      batteryLevel: (batt['level'] as num?)?.toInt(),
      batteryStatus: batt['status'] as String? ?? 'Unknown',
      charging: batt['charging'] == true,
      batteryTempC: (batt['temperature'] as num?)?.toDouble(),
      batteryVoltage: (batt['voltage'] as num?)?.toDouble(),
      batteryCurrentMa: (batt['current'] as num?)?.toDouble(),
      batteryPlugged: batt['plugged'] as String? ?? 'Unknown',
      batteryHealth: batt['health'] as String? ?? 'Unknown',
      batteryRatePerHour: (batt['ratePercentPerHour'] as num?)?.toDouble(),
      batteryEstimateMinutes: (batt['estimateMinutes'] as num?)?.toDouble(),
      thermalStatus: therm['statusLabel'] as String? ?? 'Unknown',
      thermalZones: (therm['zones'] as List?)
              ?.whereType<Map>()
              .map(
                (e) => ThermalZone(
                  name: e['name']?.toString() ?? '',
                  type: e['type']?.toString() ?? '',
                  celsius: (e['celsius'] as num?)?.toDouble() ?? 0,
                ),
              )
              .toList(growable: false) ??
          const [],
      thermalReason: therm['zonesReason'] as String?,
      rxPerSec: (net['rxPerSec'] as num?)?.toDouble(),
      txPerSec: (net['txPerSec'] as num?)?.toDouble(),
      uidRxPerSec: (net['uidRxPerSec'] as num?)?.toDouble(),
      uidTxPerSec: (net['uidTxPerSec'] as num?)?.toDouble(),
      throughputSupported: net['supported'] == true,
    );
  }

  final DateTime at;
  final List<CoreSample> cores;
  final double? cpuLoad;
  final int coreCount;
  final String? governor;
  final bool cpuLoadReadable;
  final bool cpuFreqReadable;

  final int memTotal;
  final int memAvailable;
  final int memUsed;
  final int memThreshold;
  final bool lowMemory;
  final int selfPssBytes;

  final int? batteryLevel;
  final String batteryStatus;
  final bool charging;
  final double? batteryTempC;
  final double? batteryVoltage;
  final double? batteryCurrentMa;
  final String batteryPlugged;
  final String batteryHealth;
  final double? batteryRatePerHour;
  final double? batteryEstimateMinutes;

  final String thermalStatus;
  final List<ThermalZone> thermalZones;
  final String? thermalReason;

  final double? rxPerSec;
  final double? txPerSec;
  final double? uidRxPerSec;
  final double? uidTxPerSec;
  final bool throughputSupported;

  double get memFraction => memTotal <= 0 ? 0 : memUsed / memTotal;

  double? get hottestZone =>
      thermalZones.isEmpty ? null : thermalZones.map((z) => z.celsius).reduce((a, b) => a > b ? a : b);
}

@immutable
class ThermalZone {
  const ThermalZone({required this.name, required this.type, required this.celsius});

  final String name;
  final String type;
  final double celsius;
}
