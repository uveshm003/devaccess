import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/platform/channels.dart';
import 'core/state/app_settings.dart';
import 'core/state/info_controller.dart';
import 'core/state/monitor_controller.dart';
import 'core/state/services.dart';
import 'core/state/tier_controller.dart';
import 'core/state/toggle_controller.dart';

/// DevAccess — developer options and device insight hub.
///
/// NFR-PERF-1 — startup does the minimum: build the controllers, restore preferences and
/// hand off to the UI. Tier detection and the first dashboard section load in the
/// background once the first frame is up.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge: content runs under the status and gesture bars, and the bar icons are
  // re-tinted per theme by the AnnotatedRegion in DevAccessApp.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // NFR-RELIABILITY-1 — a widget that throws must not put a red box in front of a user.
  // In release the frame degrades to a quiet, on-brand placeholder instead.
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const _FrameFailed();
  }

  final bridge = DevAccessBridge.instance..startListeningForRoutes();
  final settings = AppSettings(bridge);
  final tier = TierController(bridge);
  final info = InfoController(bridge);
  final toggles = ToggleController(bridge, tier, settings);
  final monitor = MonitorController(bridge)..attach();

  // Preferences gate the theme, so this one await happens before the first frame.
  await settings.load();
  info.refreshInterval = settings.infoRefreshMs;

  runApp(
    Services(
      bridge: bridge,
      settings: settings,
      tier: tier,
      info: info,
      toggles: toggles,
      monitor: monitor,
      child: const DevAccessApp(),
    ),
  );
}

/// Replaces the framework's red error box in release builds.
class _FrameFailed extends StatelessWidget {
  const _FrameFailed();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFF0A0D11),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This section could not be drawn.',
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: TextStyle(color: Color(0xFFA3ADBA), fontSize: 13),
            ),
          ),
        ),
      );
}
