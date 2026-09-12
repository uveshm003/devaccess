import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/l10n/strings.dart';
import 'core/state/services.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';

/// The root widget: theme, localisation and the navigation shell.
class DevAccessApp extends StatefulWidget {
  const DevAccessApp({super.key});

  @override
  State<DevAccessApp> createState() => _DevAccessAppState();
}

class _DevAccessAppState extends State<DevAccessApp> {
  Color? _dynamicSeed;

  @override
  void initState() {
    super.initState();
    _loadDynamicColour();
  }

  /// FR-SET-1 — Material You seeding, where the platform offers it (Android 12+).
  Future<void> _loadDynamicColour() async {
    final seed = await Services.read(context).bridge.dynamicColorSeed();
    if (mounted && seed != null) setState(() => _dynamicSeed = seed);
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    return ListenableBuilder(
      listenable: services.settings,
      builder: (context, _) {
        final settings = services.settings;
        final seed =
            (settings.dynamicColour ? _dynamicSeed : null) ?? settings.accent;
        return MaterialApp(
          title: 'DevAccess',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: AppTheme.light(seed, null),
          darkTheme: AppTheme.dark(seed, null),
          // NFR-I18N-1 — strings come from a delegate, and the tree is RTL-tolerant.
          localizationsDelegates: const [
            AppStringsDelegate(),
            ...GlobalMaterialLocalizationsShim.delegates,
          ],
          supportedLocales: AppStringsDelegate.supportedLocales,
          builder: (context, child) {
            // NFR-A11Y-1 — respect the user's font scale, but keep layouts usable at the
            // extremes rather than letting rows collide.
            final media = MediaQuery.of(context);
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              // The bars are transparent and the app draws under them, so their icons have
              // to be re-tinted whenever the theme flips.
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
                systemNavigationBarContrastEnforced: false,
              ),
              child: MediaQuery(
                data: media.copyWith(
                  textScaler:
                      media.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.6),
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const AppShell(),
        );
      },
    );
  }
}

/// The Material/Widgets/Cupertino delegates, kept in one place so adding
/// `flutter_localizations` later is a one-line change (NFR-I18N-1).
abstract final class GlobalMaterialLocalizationsShim {
  static const delegates = <LocalizationsDelegate<Object>>[
    DefaultMaterialLocalizations.delegate,
    DefaultWidgetsLocalizations.delegate,
  ];
}
