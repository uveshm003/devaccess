import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/platform/channels.dart';
import '../../core/state/services.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/launcher_catalog.dart';
import '../../widgets/brand.dart';
import '../home/home_screen.dart';
import '../info/info_screen.dart';
import '../launchers/launchers_screen.dart';
import '../more/more_screen.dart';
import '../toggles/toggles_screen.dart';

/// The five-destination navigation shell.
///
/// NFR-COMPAT-2 — switches to a [NavigationRail] on wide windows so foldables, tablets and
/// resized multi-window sessions get a sensible layout instead of a stretched bottom bar.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  StreamSubscription<NativeRoute>? _routeSub;

  @override
  void initState() {
    super.initState();
    // Kick off the background warm-up after the first frame (NFR-PERF-1).
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final services = Services.read(context);
    await services.tier.refresh(probeRoot: services.settings.probeRootOnStart);
    unawaited(services.info.loadIndex());
    unawaited(services.toggles.refreshAll());
    unawaited(services.monitor.refreshServiceState());
    unawaited(_publishShortcuts());
    _routeSub = services.bridge.routes.listen(_handleNativeRoute);
  }

  /// FR-SURF-3 — publish the launcher shortcuts from the current favourites, falling back
  /// to a sensible default set so a fresh install still has useful long-press actions.
  Future<void> _publishShortcuts() async {
    final services = Services.read(context);
    final ids = services.settings.favouriteLaunchers.isEmpty
        ? const ['dev_options', 'wifi']
        : services.settings.favouriteLaunchers;
    final items = <Map<String, dynamic>>[
      for (final id in ids.take(3))
        if (LauncherCatalog.byId(id) case final spec?)
          {'id': spec.id, 'label': spec.label, 'route': 'launchers', 'target': spec.id},
      {'id': 'report', 'label': 'Device report', 'route': 'info', 'target': 'report'},
    ];
    await services.bridge.setShortcuts(items);
  }

  /// A tile, shortcut or notification asked for a specific screen.
  void _handleNativeRoute(NativeRoute route) {
    if (!mounted) return;
    final index = switch (route.route) {
      'launchers' => 1,
      'toggles' => 2,
      'info' => 3,
      'monitor' => 4,
      _ => 0,
    };
    // Drop any pushed detail screen so the requested tab is what the user lands on.
    Navigator.of(context).popUntil((r) => r.isFirst);
    setState(() => _index = index);
  }

  @override
  void dispose() {
    _routeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final destinations = <({IconData icon, IconData selected, String label})>[
      (icon: Icons.dashboard_outlined, selected: Icons.dashboard, label: strings.navHome),
      (icon: Icons.grid_view_outlined, selected: Icons.grid_view, label: strings.navLaunchers),
      (icon: Icons.toggle_on_outlined, selected: Icons.toggle_on, label: strings.navToggles),
      (icon: Icons.smartphone_outlined, selected: Icons.smartphone, label: strings.navInfo),
      (icon: Icons.more_horiz_outlined, selected: Icons.more_horiz, label: strings.navMore),
    ];

    final pages = <Widget>[
      const HomeScreen(),
      const LaunchersScreen(),
      const TogglesScreen(),
      const InfoScreen(),
      const MoreScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        // IndexedStack keeps each tab's state (search text, scroll position) alive.
        // TabVisibility tells the hidden ones to stop sampling (NFR-PERF-2).
        final body = IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < pages.length; i++)
              TabVisibility(visible: i == _index, child: pages[i]),
          ],
        );

        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                SafeArea(
                  right: false,
                  child: NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: _select,
                    labelType: NavigationRailLabelType.all,
                    // The mark anchors the rail the way the wordmark anchors the phone
                    // layout's app bar.
                    leading: const Padding(
                      padding: EdgeInsets.only(top: Insets.md, bottom: Insets.xs),
                      child: AppMark(size: 30),
                    ),
                    destinations: [
                      for (final d in destinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selected),
                          label: Text(d.label),
                          padding: const EdgeInsets.symmetric(vertical: 2),
                        ),
                    ],
                  ),
                ),
                VerticalDivider(width: 1, color: context.palette.hairline),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          body: body,
          bottomNavigationBar: DecoratedBox(
            // A hairline instead of the default elevation shadow, so the bar reads as part
            // of the same surface system as the cards above it.
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.palette.hairline)),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: d.label,
                    tooltip: d.label,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Tapping the tab you are already on pops any detail screen and returns you to the top
  /// of that tab — the behaviour every shipped tab bar has.
  void _select(int index) {
    if (index == _index) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _index = index);
  }
}

/// Convenience for pushing a full-screen route from anywhere in the shell.
Future<T?> pushScreen<T>(BuildContext context, Widget screen) =>
    Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => screen));

/// NFR-PERF-2 — tells a tab whether it is the one on screen.
///
/// The shell keeps every tab mounted so their state survives a switch, which means a tab
/// cannot rely on `deactivate` to know it has been hidden. Screens that poll or stream
/// read this and stand down when it turns false.
class TabVisibility extends InheritedWidget {
  const TabVisibility({required this.visible, required super.child, super.key});

  final bool visible;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabVisibility>()?.visible ?? true;

  @override
  bool updateShouldNotify(TabVisibility oldWidget) => oldWidget.visible != visible;
}
