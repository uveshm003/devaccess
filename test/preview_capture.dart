import 'dart:io';
import 'dart:ui' as ui;

import 'package:devaccess/core/platform/channels.dart';
import 'package:devaccess/core/state/app_settings.dart';
import 'package:devaccess/core/state/info_controller.dart';
import 'package:devaccess/core/state/monitor_controller.dart';
import 'package:devaccess/core/state/services.dart';
import 'package:devaccess/core/state/tier_controller.dart';
import 'package:devaccess/core/state/toggle_controller.dart';
import 'package:devaccess/core/theme/app_theme.dart';
import 'package:devaccess/features/home/home_screen.dart';
import 'package:devaccess/features/launchers/launchers_screen.dart';
import 'package:devaccess/features/info/info_screen.dart';
import 'package:devaccess/features/more/more_screen.dart';
import 'package:devaccess/features/monitor/monitor_screen.dart';
import 'package:devaccess/features/settings/settings_screen.dart';
import 'package:devaccess/features/tier/tier_screen.dart';
import 'package:devaccess/features/toggles/toggles_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders real screens against a canned bridge and writes PNGs, so the visual design can
/// be reviewed without a device. Not part of the normal suite — run it explicitly:
///
///     flutter test test/preview_capture.dart
///
/// Output goes to the directory named by PREVIEW_OUT (defaults to build/preview).
void main() {
  final out = Directory(
    Platform.environment['PREVIEW_OUT'] ?? 'build/preview',
  )..createSync(recursive: true);

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadRealFonts();
    _mockBridge();
  });

  for (final mode in [Brightness.dark, Brightness.light]) {
    final suffix = mode == Brightness.dark ? 'dark' : 'light';

    testWidgets('home $suffix', (tester) async {
      await _capture(tester, const HomeScreen(), mode, '${out.path}/home_$suffix.png');
    });

    testWidgets('launchers $suffix', (tester) async {
      await _capture(
          tester, const LaunchersScreen(), mode, '${out.path}/launchers_$suffix.png');
    });

    testWidgets('more $suffix', (tester) async {
      await _capture(tester, const MoreScreen(), mode, '${out.path}/more_$suffix.png');
    });

    testWidgets('toggles $suffix', (tester) async {
      await _capture(tester, const TogglesScreen(), mode, '${out.path}/toggles_$suffix.png');
    });

    testWidgets('info $suffix', (tester) async {
      await _capture(tester, const InfoScreen(), mode, '${out.path}/info_$suffix.png');
    });

    testWidgets('settings $suffix', (tester) async {
      await _capture(tester, const SettingsScreen(), mode, '${out.path}/settings_$suffix.png');
    });

    testWidgets('monitor $suffix', (tester) async {
      await _capture(tester, const MonitorScreen(), mode, '${out.path}/monitor_$suffix.png');
    });

    testWidgets('tier $suffix', (tester) async {
      await _capture(tester, const TierScreen(), mode, '${out.path}/tier_$suffix.png');
    });
  }
}

Future<void> _capture(
  WidgetTester tester,
  Widget screen,
  Brightness mode,
  String path, {
  Size size = const Size(400, 890),
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final bridge = DevAccessBridge.instance;
  final settings = AppSettings(bridge);
  final tier = TierController(bridge);
  final info = InfoController(bridge);
  final toggles = ToggleController(bridge, tier, settings);
  final monitor = MonitorController(bridge);

  // Priming talks to the (mocked) platform channel, which resolves on the real event
  // loop — it has to happen outside the test's fake-async zone.
  await tester.runAsync(() async {
    await settings.load();
    await tier.refresh();
    await info.loadIndex();
    for (final id in const ['device', 'os', 'battery', 'memory']) {
      await info.loadSection(id);
    }
    await toggles.refreshAll();
  });

  await tester.pumpWidget(
    Services(
      bridge: bridge,
      settings: settings,
      tier: tier,
      info: info,
      toggles: toggles,
      monitor: monitor,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: mode == Brightness.dark
            ? AppTheme.dark(AppTheme.brandSeed, null)
            : AppTheme.light(AppTheme.brandSeed, null),
        home: RepaintBoundary(key: const Key('shot'), child: screen),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));

  // Feed the monitor's event channel one sample so the live screens have data to draw.
  await tester.runAsync(() async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'dev.access/events/monitor',
      const StandardMethodCodec().encodeSuccessEnvelope(_sample()),
      (_) {},
    );
  });
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));

  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });

  // Dispose the tree so the screens' periodic timers and tickers are cancelled before
  // the test framework checks for pending work.
  await tester.pumpWidget(const SizedBox.shrink());
  for (final c in [settings, tier, info, toggles, monitor]) {
    c.dispose();
  }
}

/// The test font draws every glyph as a box; load a real face so the type scale is
/// actually reviewable.
Future<void> _loadRealFonts() async {
  const faces = {
    'Roboto': [
      '/System/Library/Fonts/Supplemental/Arial.ttf',
      '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
    ],
  };
  for (final entry in faces.entries) {
    final loader = FontLoader(entry.key);
    var loaded = false;
    for (final path in entry.value) {
      final file = File(path);
      if (!file.existsSync()) continue;
      loaded = true;
      loader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
    }
    if (loaded) await loader.load();
  }
}

void _mockBridge() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  // Event channels: accept listen/cancel so the streams open; samples are pushed by hand.
  for (final name in const [
    'dev.access/events/monitor',
    'dev.access/events/sensors',
    'dev.access/events/net',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (call) async => null);
  }

  const channel = MethodChannel('dev.access/method');
  messenger.setMockMethodCallHandler(channel, (call) async {
    switch (call.method) {
      case 'prefs.load':
        return null;
      case 'prefs.save':
        return true;
      case 'app.info':
        return {
          'packageName': 'com.devaccess.app.foss',
          'versionName': '1.0.0',
          'versionCode': 1,
          'flavor': 'foss',
          'sdkInt': 35,
        };
      case 'app.dynamicColor':
        return null;
      case 'tier.status':
        return {
          'tier': 2,
          'writeSettings': true,
          'writeSecureSettings': true,
          'sdkInt': 35,
          'flavor': 'foss',
          'fullAccessBuild': true,
          'packageName': 'com.devaccess.app.foss',
        };
      case 'info.index':
        return const [
          {'id': 'device', 'title': 'Device & Build', 'live': false},
          {'id': 'os', 'title': 'OS & Security', 'live': false},
          {'id': 'battery', 'title': 'Battery', 'live': true},
          {'id': 'memory', 'title': 'Memory', 'live': true},
        ];
      case 'info.section':
        return _section(
          (call.arguments as Map)['id'] as String? ?? 'device',
        );
      case 'settings.readMany':
        return [
          for (final item in (call.arguments as Map)['items'] as List)
            {
              'scope': (item as Map)['scope'],
              'key': item['key'],
              's': 'ok',
              'v': item['key'] == 'adb_enabled' ? '0' : '1',
            },
        ];
      case 'settings.read':
        return {'s': 'ok', 'v': '1'};
      case 'monitor.snapshot':
        return _sample();
      case 'monitor.serviceRunning':
        return false;
      case 'surface.setShortcuts':
        return {'ok': true};
      default:
        return null;
    }
  });
}

Map<String, Object?> _section(String id) => switch (id) {
      'device' => {
          'id': 'device',
          'title': 'Device & Build',
          'live': false,
          'fields': [
            {'k': 'manufacturer', 'l': 'Manufacturer', 's': 'ok', 'v': 'Google'},
            {'k': 'model', 'l': 'Model', 's': 'ok', 'v': 'Pixel 9 Pro'},
            {'k': 'socModel', 'l': 'SoC model', 's': 'ok', 'v': 'Tensor G4'},
            {'k': 'board', 'l': 'Board', 's': 'ok', 'v': 'caiman'},
            {'k': 'buildType', 'l': 'Build type', 's': 'ok', 'v': 'user'},
            {'k': 'serial', 'l': 'Serial number', 's': 'restricted', 'r': 'Needs privileged access since API 29'},
          ],
        },
      'os' => {
          'id': 'os',
          'title': 'OS & Security',
          'live': false,
          'fields': [
            {'k': 'release', 'l': 'Android release', 's': 'ok', 'v': '15'},
            {'k': 'sdkInt', 'l': 'API level', 's': 'ok', 'v': 35},
            {'k': 'securityPatch', 'l': 'Security patch', 's': 'ok', 'v': '2026-08-05'},
            {'k': 'selinux', 'l': 'SELinux mode', 's': 'ok', 'v': 'Enforcing'},
            {'k': 'bootloaderLocked', 'l': 'Bootloader lock state', 's': 'ok', 'v': 'Locked'},
          ],
        },
      'battery' => {
          'id': 'battery',
          'title': 'Battery',
          'live': true,
          'fields': [
            {'k': 'level', 'l': 'Level', 's': 'ok', 'v': '68%'},
            {'k': 'health', 'l': 'Health', 's': 'ok', 'v': 'Good'},
            {'k': 'temperature', 'l': 'Temperature', 's': 'ok', 'v': '31.4 °C'},
          ],
        },
      _ => {
          'id': 'memory',
          'title': 'Memory',
          'live': true,
          'fields': [
            {'k': 'total', 'l': 'Total', 's': 'ok', 'v': '15.4 GiB'},
            {'k': 'available', 'l': 'Available', 's': 'ok', 'v': '6.1 GiB'},
          ],
        },
    };

Map<String, Object?> _sample() => {
      'at': DateTime.now().millisecondsSinceEpoch,
      'cpu': {'totalLoad': 34.2, 'coreCount': 8, 'loadReadable': true, 'freqReadable': true},
      'memory': {
        'total': 16642998272,
        'available': 6553600000,
        'used': 10089398272,
        'threshold': 402653184,
      },
      'battery': {
        'level': 68,
        'status': 'Charging',
        'charging': true,
        'temperature': 31.4,
      },
      'thermal': {
        'statusLabel': 'None',
        'zones': [
          {'name': 'soc', 'type': 'SOC', 'celsius': 38.2},
        ],
      },
      'network': {'supported': true, 'rxPerSec': 148000.0, 'txPerSec': 22000.0},
    };
