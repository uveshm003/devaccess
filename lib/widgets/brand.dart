import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// The DevAccess mark: a terminal prompt (`>_`) in a rounded tile.
///
/// Drawn rather than shipped as an asset so it inherits the accent, scales to any density
/// and costs nothing in app size. The same geometry is mirrored in the Android adaptive
/// icon and the splash vector, so the launcher, the splash and the app bar all match.
class AppMark extends StatelessWidget {
  const AppMark({this.size = 32, this.colour, this.onColour, super.key});

  final double size;

  /// Tile colour; defaults to the accent.
  final Color? colour;

  /// Glyph colour; defaults to the accent's on-colour.
  final Color? onColour;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final base = colour ?? scheme.primary;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MarkPainter(
          top: Color.lerp(base, Colors.white, 0.22)!,
          bottom: Color.lerp(base, Colors.black, 0.08)!,
          glyph: onColour ?? scheme.onPrimary,
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.top, required this.bottom, required this.glyph});

  final Color top;
  final Color bottom;
  final Color glyph;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Rect.fromLTWH(0, 0, s, s);
    final tile = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.28));

    canvas.drawRRect(
      tile,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ).createShader(rect),
    );

    final stroke = Paint()
      ..color = glyph
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // `>` — the prompt.
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.30, s * 0.31)
        ..lineTo(s * 0.52, s * 0.50)
        ..lineTo(s * 0.30, s * 0.69),
      stroke,
    );
    // `_` — the cursor.
    canvas.drawLine(Offset(s * 0.57, s * 0.69), Offset(s * 0.74, s * 0.69), stroke);
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.top != top || old.bottom != bottom || old.glyph != glyph;
}

/// Mark plus wordmark, for app bars, the About row and empty states.
class AppWordmark extends StatelessWidget {
  const AppWordmark({this.size = 28, this.subtitle, super.key});

  final double size;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppMark(size: size),
        SizedBox(width: size * 0.32),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Dev',
                    style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: 'Access',
                    style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              style: context.texts.titleLarge?.copyWith(
                fontSize: size * 0.72,
                letterSpacing: -0.4,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: context.texts.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.6,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
