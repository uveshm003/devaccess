import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import 'sparkline.dart';

/// Section header used across the screens.
///
/// The label is small, tracked-out and tinted — the "shipping product" convention for
/// separating groups without spending a whole heading on them.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {this.trailing, this.subtitle, this.icon, super.key});

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.md, Insets.xs, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: theme.colorScheme.primary),
            const SizedBox(width: 7),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    fontSize: 11.5,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The one card shape in the app: hairline border, no shadow, optional tap.
///
/// [Card] covers most cases through the theme; this exists for the places that need to own
/// their padding or wrap content that is not a list.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(Insets.md),
    this.margin = const EdgeInsets.symmetric(horizontal: Insets.gutter, vertical: 6),
    this.onTap,
    this.colour,
    this.border,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? colour;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      padding: margin,
      child: Material(
        color: colour ?? scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: Corners.rLg,
          side: BorderSide(color: border ?? context.palette.hairline),
        ),
        child: InkWell(
          borderRadius: Corners.rLg,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A compact key figure used on the home dashboard and the monitor.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    this.icon,
    this.detail,
    this.progress,
    this.colour,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final String? detail;
  final IconData? icon;
  final double? progress;
  final Color? colour;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = colour ?? scheme.primary;
    return Semantics(
      label: '$label: $value${detail == null ? '' : ', $detail'}',
      button: onTap != null,
      child: Material(
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: Corners.rLg,
          side: BorderSide(color: context.palette.hairline),
        ),
        child: InkWell(
          borderRadius: Corners.rLg,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.14),
                          borderRadius: Corners.rXs,
                        ),
                        child: Icon(icon, size: 14, color: c),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                if (progress != null) ...[
                  const SizedBox(height: 9),
                  MeterBar(fraction: progress!, colour: c, height: 5),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown wherever a feature is unavailable, instead of an empty screen
/// (NFR-RELIABILITY-1).
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: Corners.rXl,
                border: Border.all(color: context.palette.hairline),
              ),
              child: Icon(icon, size: 32, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Insets.md),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: Insets.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: Insets.lg), action!],
          ],
        ),
      ),
    );
  }
}

/// A search box wired for the global search (FR-QA-6, FR-INFO-1).
class SearchBox extends StatelessWidget {
  const SearchBox({
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.trailing,
    super.key,
  });

  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xs, Insets.gutter, Insets.xxs),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: context.texts.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          border: const OutlineInputBorder(
            borderRadius: Corners.rPill,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: Corners.rPill,
            borderSide: BorderSide(color: context.palette.hairline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: Corners.rPill,
            borderSide: BorderSide(color: context.scheme.primary, width: 1.6),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 19),
                  tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
              ?trailing,
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// A short status pill (tier badge, connection type, pass/fail).
class Pill extends StatelessWidget {
  const Pill(this.text, {this.colour, this.icon, this.dense = false, super.key});

  final String text;
  final Color? colour;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = colour ?? scheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.13),
        borderRadius: Corners.rPill,
        border: Border.all(color: c.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 13, color: c),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: c,
                  fontWeight: FontWeight.w700,
                  fontSize: dense ? 10.5 : 11.5,
                ),
          ),
        ],
      ),
    );
  }
}

/// A live indicator: a dot that breathes while something is actively sampling.
class StatusDot extends StatefulWidget {
  const StatusDot({required this.colour, this.live = true, this.size = 8, super.key});

  final Color colour;
  final bool live;
  final double size;

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.live) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(StatusDot old) {
    super.didUpdateWidget(old);
    if (widget.live && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.live && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = widget.live ? 0.45 + (_controller.value * 0.55) : 1.0;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.colour.withValues(alpha: t),
            boxShadow: widget.live
                ? [
                    BoxShadow(
                      color: widget.colour.withValues(alpha: 0.35 * t),
                      blurRadius: widget.size,
                      spreadRadius: widget.size * 0.25,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}

/// Monospace value text — IDs, hashes, adb commands, raw properties.
class MonoText extends StatelessWidget {
  const MonoText(this.text, {this.style, this.maxLines, super.key});

  final String text;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: (style ?? context.texts.bodySmall)?.copyWith(
        fontFamily: context.palette.mono,
        fontFamilyFallback: const ['Roboto Mono', 'Menlo', 'Courier New'],
        height: 1.4,
      ),
    );
  }
}

/// A placeholder block for content that has not arrived yet.
///
/// A shimmering box tells the user the app is working; an empty gap tells them it is broken.
class Skeleton extends StatefulWidget {
  const Skeleton({this.width, this.height = 14, this.radius = Corners.xs, super.key});

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
            scheme.surfaceContainerHigh,
            scheme.surfaceContainerHighest,
            _controller.value,
          ),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A short fade-and-rise entrance, optionally staggered by [index].
///
/// Used once per screen on the first build so content arrives rather than snapping in.
/// NFR-A11Y-1 — collapses to a plain child when the platform asks for reduced motion.
class FadeIn extends StatelessWidget {
  const FadeIn({required this.child, this.index = 0, super.key});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      key: key,
      tween: Tween(begin: 0, end: 1),
      duration: Motion.slow,
      curve: Interval(
        (index * 0.06).clamp(0.0, 0.5),
        1,
        curve: Motion.enter,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}
