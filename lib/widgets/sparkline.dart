import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import '../core/util/formatters.dart';

/// A lightweight rolling graph for the live monitors (FR-MON — "lightweight graphs").
///
/// NFR-PERF-2 — a [CustomPainter] over a fixed-length list; no charting dependency, no
/// per-frame allocation beyond the path itself.
class Sparkline extends StatelessWidget {
  const Sparkline({
    required this.values,
    this.colour,
    this.height = 48,
    this.maxValue,
    this.minValue = 0,
    this.fill = true,
    this.label,
    super.key,
  });

  final List<double> values;
  final Color? colour;
  final double height;

  /// Fixed ceiling — pass 100 for percentages so the line does not rescale each frame.
  final double? maxValue;
  final double minValue;
  final bool fill;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = colour ?? scheme.primary;
    return Semantics(
      label: label == null
          ? null
          : '$label graph, latest ${values.isEmpty ? Fmt.dash : Fmt.axis(values.last)}',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SparklinePainter(
            values: values,
            colour: c,
            gridColour: scheme.outlineVariant.withValues(alpha: 0.4),
            maxValue: maxValue,
            minValue: minValue,
            fill: fill,
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.colour,
    required this.gridColour,
    required this.maxValue,
    required this.minValue,
    required this.fill,
  });

  final List<double> values;
  final Color colour;
  final Color gridColour;
  final double? maxValue;
  final double minValue;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColour
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (values.length < 2) return;

    var hi = maxValue ?? values.reduce((a, b) => a > b ? a : b);
    final lo = minValue;
    if (hi <= lo) hi = lo + 1;

    final dx = size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final normalised = ((values[i] - lo) / (hi - lo)).clamp(0.0, 1.0);
      final x = dx * i;
      final y = size.height - normalised * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (fill) {
      final area = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colour.withValues(alpha: 0.28), colour.withValues(alpha: 0.02)],
          ).createShader(Offset.zero & size),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = colour
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values.length != values.length ||
      (values.isNotEmpty && old.values.isNotEmpty && old.values.last != values.last) ||
      old.colour != colour;
}

/// A horizontal bar used for per-core load and memory pressure.
class MeterBar extends StatelessWidget {
  const MeterBar({
    required this.fraction,
    this.colour,
    this.height = 6,
    this.label,
    super.key,
  });

  final double fraction;
  final Color? colour;
  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final f = fraction.clamp(0.0, 1.0);
    return Semantics(
      label: label == null ? null : '$label ${(f * 100).round()} percent',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        // The bar eases to a new reading rather than snapping, so a sampled value
        // reads as a moving gauge instead of a flicker.
        child: TweenAnimationBuilder<double>(
          duration: Motion.base,
          curve: Motion.enter,
          tween: Tween<double>(begin: 0, end: f),
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            minHeight: height,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(colour ?? scheme.primary),
          ),
        ),
      ),
    );
  }
}
