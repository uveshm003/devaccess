import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// FR-SET-1 — Material 3 theming with light/dark/system, dynamic colour and a chosen accent.
///
/// The scheme is generated from a seed so Material You and the accent picker keep working,
/// but the neutral ramp, the type scale and every component shape are authored here rather
/// than left at the framework defaults. That is the difference between "a Flutter app" and
/// a product: cards sit on an off-white page behind a hairline, numbers are tabular, and
/// the density is consistent from the dashboard to the audit log.
///
/// NFR-A11Y-1 — sizes stay on the Material type scale so system font scaling applies, and
/// every colour pair is drawn from the generated [ColorScheme] so contrast holds in both
/// brightnesses.
abstract final class AppTheme {
  /// DevAccess signal green. Used for the launcher icon, the splash and the default accent,
  /// so a fresh install looks like the product rather than like the framework.
  static const Color brandSeed = Color(0xFF2ED3A5);

  static ThemeData light(Color seed, ColorScheme? dynamicScheme) => _build(
        _ramp(
          dynamicScheme ?? ColorScheme.fromSeed(seedColor: seed),
          Brightness.light,
        ),
        Brightness.light,
      );

  static ThemeData dark(Color seed, ColorScheme? dynamicScheme) => _build(
        _ramp(
          dynamicScheme ??
              ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
          Brightness.dark,
        ),
        Brightness.dark,
      );

  // ---------------------------------------------------------------------------
  // Neutrals
  // ---------------------------------------------------------------------------

  /// Replaces the generated neutral ramp with an authored one.
  ///
  /// `fromSeed` produces greys that carry a lot of the seed's chroma, which makes every
  /// seeded app look the same shade of lilac or beige. These neutrals are cool and near-flat,
  /// then blended a few percent back toward the accent so a Material You palette still reads
  /// as one system.
  static ColorScheme _ramp(ColorScheme s, Brightness brightness) {
    final accent = s.primary;
    Color tint(int value, double amount) =>
        Color.lerp(Color(value), accent, amount) ?? Color(value);

    if (brightness == Brightness.light) {
      return s.copyWith(
        surface: tint(0xFFFBFBFC, 0.02),
        surfaceDim: tint(0xFFEDEFF3, 0.03),
        surfaceBright: const Color(0xFFFFFFFF),
        surfaceContainerLowest: const Color(0xFFFFFFFF),
        surfaceContainerLow: const Color(0xFFFFFFFF),
        surfaceContainer: tint(0xFFF4F6F8, 0.03),
        surfaceContainerHigh: tint(0xFFEEF0F4, 0.04),
        surfaceContainerHighest: tint(0xFFE8EBEF, 0.05),
        onSurface: tint(0xFF0F141B, 0.02),
        onSurfaceVariant: tint(0xFF57616F, 0.04),
        outline: tint(0xFF8D96A3, 0.05),
        outlineVariant: tint(0xFFDDE2E8, 0.05),
      );
    }
    return s.copyWith(
      surface: tint(0xFF0A0D11, 0.02),
      surfaceDim: tint(0xFF080A0E, 0.02),
      surfaceBright: tint(0xFF232932, 0.04),
      surfaceContainerLowest: tint(0xFF06080B, 0.02),
      surfaceContainerLow: tint(0xFF11151B, 0.03),
      surfaceContainer: tint(0xFF151A21, 0.04),
      surfaceContainerHigh: tint(0xFF1B212A, 0.05),
      surfaceContainerHighest: tint(0xFF222933, 0.06),
      onSurface: tint(0xFFE8ECF1, 0.03),
      onSurfaceVariant: tint(0xFFA3ADBA, 0.05),
      outline: tint(0xFF69727F, 0.05),
      outlineVariant: tint(0xFF2A313C, 0.07),
    );
  }

  // ---------------------------------------------------------------------------
  // Type
  // ---------------------------------------------------------------------------

  /// Tightens the Material scale: display and headline sizes get negative tracking and
  /// heavier weights (the "indie product" look), body copy gets a comfortable line height,
  /// and labels get the weight they need to read as UI rather than prose.
  static TextTheme _type(TextTheme base) => base.copyWith(
        displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1.2),
        displayMedium:
            base.displayMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1.0),
        displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.8),
        headlineLarge:
            base.headlineLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.6),
        headlineMedium:
            base.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineSmall:
            base.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
        titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.1),
        titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: base.bodyLarge?.copyWith(height: 1.45),
        bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
        bodySmall: base.bodySmall?.copyWith(height: 1.4),
        labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.1),
        labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
        labelSmall: base.labelSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.4),
      );

  // ---------------------------------------------------------------------------
  // Components
  // ---------------------------------------------------------------------------

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);
    final text = _type(base.textTheme);
    final dark = brightness == Brightness.dark;

    // A hairline rather than a shadow: in dark mode a shadow is invisible, and in light mode
    // a stack of elevated cards turns into mush. One consistent border reads on both.
    final hairline = dark
        ? scheme.outlineVariant.withValues(alpha: 0.55)
        : scheme.outlineVariant.withValues(alpha: 0.9);

    final palette = dark
        ? AppPalette.dark(
            hairline: hairline,
            heroTop: Color.lerp(scheme.surface, scheme.primary, 0.16)!,
            heroBottom: scheme.surface,
          )
        : AppPalette.light(
            hairline: hairline,
            heroTop: Color.lerp(scheme.surface, scheme.primary, 0.13)!,
            heroBottom: scheme.surface,
          );

    final cardShape = RoundedRectangleBorder(
      borderRadius: Corners.rLg,
      side: BorderSide(color: hairline),
    );

    return base.copyWith(
      extensions: [palette],
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,

      // Predictive back on Android, the platform slide elsewhere — the transition users
      // already expect from a first-party app.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 60,
        titleSpacing: Insets.gutter,
        titleTextStyle: text.titleLarge?.copyWith(fontSize: 21, color: scheme.onSurface),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
        actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: Insets.gutter, vertical: 6),
        shape: cardShape,
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: dark
            ? scheme.surfaceContainerLow
            : scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: dark ? 0.20 : 0.14),
        indicatorShape: const RoundedRectangleBorder(borderRadius: Corners.rMd),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontSize: 11.5,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: dark ? scheme.surfaceContainerLow : scheme.surfaceContainerLowest,
        indicatorColor: scheme.primary.withValues(alpha: dark ? 0.20 : 0.14),
        indicatorShape: const RoundedRectangleBorder(borderRadius: Corners.rMd),
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 23),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 23),
        selectedLabelTextStyle: text.labelMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        useIndicator: true,
      ),

      listTileTheme: ListTileThemeData(
        // NFR-A11Y-1 — keeps rows above the 48dp minimum touch target.
        minVerticalPadding: 12,
        horizontalTitleGap: 14,
        iconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 2),
        titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600, height: 1.25),
        subtitleTextStyle: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        leadingAndTrailingTextStyle:
            text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? scheme.surfaceContainer : scheme.surfaceContainerHigh,
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(borderRadius: Corners.rMd, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: Corners.rMd,
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Corners.rMd,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Corners.rMd,
          borderSide: BorderSide(color: scheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 14),
      ),

      chipTheme: base.chipTheme.copyWith(
        backgroundColor: dark ? scheme.surfaceContainer : scheme.surfaceContainerLowest,
        side: BorderSide(color: hairline),
        labelStyle: text.labelLarge?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: text.labelLarge?.copyWith(color: scheme.onSurface),
        iconTheme: IconThemeData(size: 18, color: scheme.primary),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: const RoundedRectangleBorder(borderRadius: Corners.rPill),
        showCheckmark: false,
        selectedColor: scheme.primary.withValues(alpha: dark ? 0.22 : 0.14),
        elevation: 0,
        pressElevation: 0,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          shape: const RoundedRectangleBorder(borderRadius: Corners.rSm),
          textStyle: text.labelLarge?.copyWith(fontSize: 14.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          side: BorderSide(color: scheme.outlineVariant),
          shape: const RoundedRectangleBorder(borderRadius: Corners.rSm),
          textStyle: text.labelLarge?.copyWith(fontSize: 14.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 42),
          padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
          shape: const RoundedRectangleBorder(borderRadius: Corners.rSm),
          textStyle: text.labelLarge?.copyWith(fontSize: 14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          highlightColor: scheme.primary.withValues(alpha: 0.10),
          shape: const RoundedRectangleBorder(borderRadius: Corners.rSm),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primary.withValues(alpha: dark ? 0.22 : 0.14),
          selectedForegroundColor: dark ? scheme.primary : scheme.onSurface,
          side: BorderSide(color: hairline),
          textStyle: text.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: Corners.rSm),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 2,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const RoundedRectangleBorder(borderRadius: Corners.rMd),
      ),

      dividerTheme: DividerThemeData(color: hairline, space: 1, thickness: 1),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.fromLTRB(Insets.sm, Insets.sm, Insets.sm, Insets.md),
        backgroundColor: dark ? scheme.surfaceContainerHighest : const Color(0xFF1B222B),
        contentTextStyle: text.bodyMedium?.copyWith(
          color: dark ? scheme.onSurface : Colors.white,
        ),
        actionTextColor: scheme.primary,
        elevation: 3,
        shape: const RoundedRectangleBorder(borderRadius: Corners.rSm),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: Corners.rXl,
          side: BorderSide(color: hairline),
        ),
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surfaceContainerHigh,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Corners.xl)),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? scheme.surfaceContainerHighest : const Color(0xFF1B222B),
          borderRadius: Corners.rXs,
        ),
        textStyle: text.bodySmall?.copyWith(color: dark ? scheme.onSurface : Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        waitDuration: const Duration(milliseconds: 500),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 6,
      ),

      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        trackHeight: 6,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.onPrimary : scheme.outline,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.transparent : scheme.outlineVariant,
        ),
      ),

      expansionTileTheme: ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: scheme.primary,
        collapsedIconColor: scheme.onSurfaceVariant,
        tilePadding: const EdgeInsets.symmetric(horizontal: Insets.md),
        childrenPadding: EdgeInsets.zero,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: Corners.rSm,
          side: BorderSide(color: hairline),
        ),
      ),

      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(5),
        radius: const Radius.circular(3),
        thumbColor: WidgetStatePropertyAll(scheme.outline.withValues(alpha: 0.5)),
      ),

      tabBarTheme: TabBarThemeData(
        dividerColor: hairline,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        indicatorSize: TabBarIndicatorSize.tab,
      ),
    );
  }

  /// Accent choices offered when dynamic colour is off or unavailable.
  static const accents = <String, Color>{
    'Signal': brandSeed,
    'Cobalt': Color(0xFF3B82F6),
    'Violet': Color(0xFF8B5CF6),
    'Amber': Color(0xFFF59E0B),
    'Rose': Color(0xFFF43F5E),
    'Slate': Color(0xFF64748B),
  };

  /// Semantic colours for status pills. These deliberately ignore the accent: a battery at
  /// 4% must not turn "fine" green because the user picked a green accent.
  static Color statusOk(BuildContext context) => AppPalette.of(context).success;

  static Color statusWarn(BuildContext context) => AppPalette.of(context).warning;

  static Color statusBad(BuildContext context) => AppPalette.of(context).danger;
}
