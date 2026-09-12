import 'dart:math' as math;

/// FR-SET-2 — user-selectable units.
enum ByteUnit {
  binary('MiB (1024-based)'),
  decimal('MB (1000-based)');

  const ByteUnit(this.label);

  final String label;
}

enum TemperatureUnit {
  celsius('°C'),
  fahrenheit('°F');

  const TemperatureUnit(this.symbol);

  final String symbol;
}

/// Shared value formatting. Everything is null-tolerant so an unavailable reading renders
/// as an em dash rather than blowing up a widget build (NFR-RELIABILITY-1).
abstract final class Fmt {
  static const dash = '—';

  static String bytes(num? value, {ByteUnit unit = ByteUnit.binary, int decimals = 1}) {
    if (value == null || value < 0) return dash;
    final base = unit == ByteUnit.binary ? 1024 : 1000;
    final units = unit == ByteUnit.binary
        ? const ['B', 'KiB', 'MiB', 'GiB', 'TiB']
        : const ['B', 'kB', 'MB', 'GB', 'TB'];
    var v = value.toDouble();
    var i = 0;
    while (v >= base && i < units.length - 1) {
      v /= base;
      i++;
    }
    return i == 0 ? '${value.toInt()} B' : '${v.toStringAsFixed(decimals)} ${units[i]}';
  }

  static String rate(num? bytesPerSecond, {ByteUnit unit = ByteUnit.binary}) =>
      bytesPerSecond == null ? dash : '${bytes(bytesPerSecond, unit: unit)}/s';

  static String temperature(double? celsius, TemperatureUnit unit) {
    if (celsius == null) return dash;
    final v = unit == TemperatureUnit.celsius ? celsius : celsius * 9 / 5 + 32;
    return '${v.toStringAsFixed(1)} ${unit.symbol}';
  }

  static String percent(num? value, {int decimals = 0}) =>
      value == null ? dash : '${value.toStringAsFixed(decimals)}%';

  static String frequency(int? kHz) {
    if (kHz == null || kHz <= 0) return dash;
    return kHz >= 1000000
        ? '${(kHz / 1000000).toStringAsFixed(2)} GHz'
        : '${(kHz / 1000).toStringAsFixed(0)} MHz';
  }

  static String duration(Duration? d) {
    if (d == null) return dash;
    final days = d.inDays;
    final h = d.inHours % 24;
    final m = d.inMinutes % 60;
    if (days > 0) return '${days}d ${h}h ${m}m';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${d.inSeconds % 60}s';
  }

  static String minutes(double? value) {
    if (value == null || value.isNaN || value.isInfinite || value <= 0) return dash;
    return duration(Duration(minutes: value.round()));
  }

  static String timestamp(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${_pad2(t.month)}-${_pad2(t.day)} '
      '${_pad2(t.hour)}:${_pad2(t.minute)}:${_pad2(t.second)}';

  static String time(DateTime t) => '${_pad2(t.hour)}:${_pad2(t.minute)}:${_pad2(t.second)}';

  static String _pad2(int v) => v.toString().padLeft(2, '0');

  static String milliseconds(num? ms) =>
      ms == null ? dash : '${ms.toStringAsFixed(ms < 10 ? 1 : 0)} ms';

  /// Compact fixed-width number for graph axis labels.
  static String axis(double v) {
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v.abs() >= 10) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  static double roundTo(double v, int decimals) {
    final f = math.pow(10, decimals);
    return (v * f).round() / f;
  }
}
