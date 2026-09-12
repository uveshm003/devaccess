import 'package:flutter/widgets.dart';

import '../platform/channels.dart';
import 'app_settings.dart';
import 'info_controller.dart';
import 'monitor_controller.dart';
import 'tier_controller.dart';
import 'toggle_controller.dart';

/// T-ARCH-3 — the composition root.
///
/// A plain [InheritedWidget] holding the capability/tier service, the data controllers and
/// the bridge. No third-party state package: the whole app is `ChangeNotifier` +
/// `ListenableBuilder`, which keeps the dependency surface at zero (G6).
class Services extends InheritedWidget {
  const Services({
    required this.bridge,
    required this.settings,
    required this.tier,
    required this.info,
    required this.toggles,
    required this.monitor,
    required super.child,
    super.key,
  });

  final DevAccessBridge bridge;
  final AppSettings settings;
  final TierController tier;
  final InfoController info;
  final ToggleController toggles;
  final MonitorController monitor;

  static Services of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<Services>();
    assert(s != null, 'Services.of() called outside the DevAccess widget tree');
    return s!;
  }

  /// Non-listening lookup, for callbacks that only need to call a method.
  static Services read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<Services>();
    assert(element != null, 'Services.read() called outside the DevAccess widget tree');
    return element!.widget as Services;
  }

  @override
  bool updateShouldNotify(Services oldWidget) =>
      bridge != oldWidget.bridge ||
      settings != oldWidget.settings ||
      tier != oldWidget.tier ||
      info != oldWidget.info ||
      toggles != oldWidget.toggles ||
      monitor != oldWidget.monitor;
}
