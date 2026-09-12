import 'package:flutter/material.dart';

/// The design tokens every screen builds on.
///
/// One scale for space, one for radius, one for motion. Screens pick from these rather
/// than inventing numbers, which is what keeps a 20-screen app feeling like one product.
abstract final class Insets {
  /// 4 — hairline gaps inside a row.
  static const double xxs = 4;

  /// 8 — between a label and its value.
  static const double xs = 8;

  /// 12 — the gutter between cards.
  static const double sm = 12;

  /// 16 — standard padding inside a card or a screen edge.
  static const double md = 16;

  /// 20 — generous card padding, hero blocks.
  static const double lg = 20;

  /// 28 — between major sections.
  static const double xl = 28;

  /// The page gutter used by every scrolling screen.
  static const double gutter = 16;

  /// Bottom padding so the last card clears the navigation bar.
  static const double scrollBottom = 40;
}

abstract final class Corners {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;

  /// Effectively a stadium; used for pills, chips and the search field.
  static const double pill = 999;

  static const BorderRadius rXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius rXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius rPill = BorderRadius.all(Radius.circular(pill));
}

abstract final class Motion {
  /// Hover/press feedback.
  static const Duration fast = Duration(milliseconds: 140);

  /// The default for a value changing on screen.
  static const Duration base = Duration(milliseconds: 260);

  /// Entrances and expansions.
  static const Duration slow = Duration(milliseconds: 420);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasised = Curves.easeInOutCubicEmphasized;
}

/// Colours that carry meaning rather than brand.
///
/// The accent is the user's to choose (and Material You may replace it entirely), so
/// "this reading is fine" and "this reading is dangerous" cannot be drawn from the scheme's
/// primary/tertiary slots — they live here and stay stable whatever the accent is.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.danger,
    required this.dangerContainer,
    required this.info,
    required this.infoContainer,
    required this.hairline,
    required this.heroTop,
    required this.heroBottom,
    required this.mono,
  });

  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color danger;
  final Color dangerContainer;
  final Color info;
  final Color infoContainer;

  /// The 1px border that separates a card from the page in both brightnesses.
  final Color hairline;

  /// The two ends of the dashboard hero wash.
  final Color heroTop;
  final Color heroBottom;

  /// Platform monospace stack, used for IDs, hashes, adb commands and raw values.
  final String mono;

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? _fallback;

  static const _fallback = AppPalette(
    success: Color(0xFF17A673),
    successContainer: Color(0xFFD7F5E9),
    warning: Color(0xFFB77400),
    warningContainer: Color(0xFFFDEFD3),
    danger: Color(0xFFC4372B),
    dangerContainer: Color(0xFFFBE0DD),
    info: Color(0xFF2563C9),
    infoContainer: Color(0xFFDCE8FF),
    hairline: Color(0x1A000000),
    heroTop: Color(0xFFE8F6F1),
    heroBottom: Color(0xFFFAFAFB),
    mono: 'monospace',
  );

  /// Light-mode semantics: deep enough to pass contrast on an off-white card.
  static AppPalette light({required Color hairline, required Color heroTop, required Color heroBottom}) =>
      AppPalette(
        success: const Color(0xFF0E8F63),
        successContainer: const Color(0xFFD5F3E7),
        warning: const Color(0xFF9A6200),
        warningContainer: const Color(0xFFFCEDCF),
        danger: const Color(0xFFB3261E),
        dangerContainer: const Color(0xFFF9DEDC),
        info: const Color(0xFF1D5DC4),
        infoContainer: const Color(0xFFDBE7FF),
        hairline: hairline,
        heroTop: heroTop,
        heroBottom: heroBottom,
        mono: 'monospace',
      );

  /// Dark-mode semantics: lifted and desaturated so they glow rather than vibrate.
  static AppPalette dark({required Color hairline, required Color heroTop, required Color heroBottom}) =>
      AppPalette(
        success: const Color(0xFF56DBA8),
        successContainer: const Color(0xFF10382A),
        warning: const Color(0xFFF5C264),
        warningContainer: const Color(0xFF3B2E10),
        danger: const Color(0xFFFF897D),
        dangerContainer: const Color(0xFF43201C),
        info: const Color(0xFF8AB4FF),
        infoContainer: const Color(0xFF16294A),
        hairline: hairline,
        heroTop: heroTop,
        heroBottom: heroBottom,
        mono: 'monospace',
      );

  /// Maps a 0..1 utilisation reading to the pill/bar colour that describes it.
  Color forLoad(double? fraction) {
    if (fraction == null) return info;
    if (fraction >= 0.9) return danger;
    if (fraction >= 0.75) return warning;
    return success;
  }

  @override
  AppPalette copyWith({
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? danger,
    Color? dangerContainer,
    Color? info,
    Color? infoContainer,
    Color? hairline,
    Color? heroTop,
    Color? heroBottom,
    String? mono,
  }) =>
      AppPalette(
        success: success ?? this.success,
        successContainer: successContainer ?? this.successContainer,
        warning: warning ?? this.warning,
        warningContainer: warningContainer ?? this.warningContainer,
        danger: danger ?? this.danger,
        dangerContainer: dangerContainer ?? this.dangerContainer,
        info: info ?? this.info,
        infoContainer: infoContainer ?? this.infoContainer,
        hairline: hairline ?? this.hairline,
        heroTop: heroTop ?? this.heroTop,
        heroBottom: heroBottom ?? this.heroBottom,
        mono: mono ?? this.mono,
      );

  @override
  AppPalette lerp(covariant ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      heroTop: Color.lerp(heroTop, other.heroTop, t)!,
      heroBottom: Color.lerp(heroBottom, other.heroBottom, t)!,
      mono: t < 0.5 ? mono : other.mono,
    );
  }
}

/// `AppPalette.of(context)` shorthand, plus the two lookups every widget needs.
extension ThemeContext on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;

  TextTheme get texts => Theme.of(this).textTheme;

  AppPalette get palette => AppPalette.of(this);
}
