import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/models/tier.dart';
import '../../core/state/services.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../apps/apps_screen.dart';
import '../monitor/monitor_screen.dart';
import '../network/network_screen.dart';
import '../report/report_screen.dart';
import '../sensors/sensors_screen.dart';
import '../settings/settings_screen.dart';
import '../shell/app_shell.dart';
import '../tier/tier_screen.dart';

typedef _Entry = ({IconData icon, String title, String subtitle, Widget screen});

/// The overflow destination: everything that is not one of the four primary tabs.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);

    final diagnostics = <_Entry>[
      (
        icon: Icons.monitor_heart_outlined,
        title: strings.monitorTitle,
        subtitle: 'CPU, memory, battery, thermal and throughput',
        screen: const MonitorScreen(),
      ),
      (
        icon: Icons.sensors_rounded,
        title: strings.sensorsTitle,
        subtitle: 'Enumeration, live values and self-tests',
        screen: const SensorsScreen(),
      ),
      (
        icon: Icons.lan_outlined,
        title: strings.networkTitle,
        subtitle: 'Connection detail, Wi-Fi, cellular and network tools',
        screen: const NetworkScreen(),
      ),
      (
        icon: Icons.apps_rounded,
        title: strings.appsTitle,
        subtitle: 'Installed packages, versions and per-app screens',
        screen: const AppsScreen(),
      ),
    ];

    final app = <_Entry>[
      (
        icon: Icons.description_outlined,
        title: strings.reportTitle,
        subtitle: 'Full report, bug snippet, share and export',
        screen: const ReportScreen(),
      ),
      (
        icon: Icons.shield_outlined,
        title: strings.tierScreenTitle,
        subtitle: 'Current tier, unlock wizard and integrity signals',
        screen: const TierScreen(),
      ),
      (
        icon: Icons.tune_rounded,
        title: strings.settingsTitle,
        subtitle: 'Theme, units, sampling, backup and privacy',
        screen: const SettingsScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(strings.navMore)),
      body: ListenableBuilder(
        listenable: services.tier,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: Insets.scrollBottom),
          children: [
            const FadeIn(child: _TierSummary()),
            FadeIn(
              index: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader('Diagnostics', icon: Icons.insights_rounded),
                  _EntryGroup(entries: diagnostics),
                ],
              ),
            ),
            FadeIn(
              index: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader('App', icon: Icons.settings_outlined),
                  _EntryGroup(entries: app),
                ],
              ),
            ),
            const FadeIn(index: 3, child: _About()),
          ],
        ),
      ),
    );
  }
}

/// One card holding several rows, rather than one card per row: fewer borders, and the
/// grouping itself carries meaning.
class _EntryGroup extends StatelessWidget {
  const _EntryGroup({required this.entries});

  final List<_Entry> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 64, color: context.palette.hairline),
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(Insets.sm, 6, Insets.sm, 6),
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: Corners.rSm,
                ),
                child: Icon(entries[i].icon, size: 19, color: scheme.primary),
              ),
              title: Text(entries[i].title),
              subtitle: Text(entries[i].subtitle),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
              onTap: () => pushScreen(context, entries[i].screen),
            ),
          ],
        ],
      ),
    );
  }
}

class _TierSummary extends StatelessWidget {
  const _TierSummary();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);
    final palette = context.palette;
    final status = services.tier.status;
    final tier = status.tier;

    final colour = switch (tier) {
      AccessTier.t0 => context.scheme.onSurfaceVariant,
      AccessTier.t1 => palette.info,
      AccessTier.t2 => palette.success,
      AccessTier.t3 => palette.warning,
    };

    return AppCard(
      onTap: () => pushScreen(context, const TierScreen()),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.13),
              borderRadius: Corners.rSm,
              border: Border.all(color: colour.withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.shield_outlined, color: colour, size: 21),
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.currentTier.toUpperCase(),
                  style: context.texts.labelSmall?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                    letterSpacing: 0.9,
                  ),
                ),
                Text(
                  '${tier.code} — ${tier.title}',
                  style: context.texts.titleMedium?.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 3),
                Text(
                  status.flavor == 'foss'
                      ? 'Off-Play build: full package visibility and the intent tester are enabled.'
                      : 'Play-policy build.',
                  style: context.texts.bodySmall
                      ?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// The signature block. An offline tool with no account and no telemetry should say so
/// where people look for it.
class _About extends StatefulWidget {
  const _About();

  @override
  State<_About> createState() => _AboutState();
}

class _AboutState extends State<_About> {
  Map<String, dynamic>? _info;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final info = await Services.read(context).bridge.appInfo();
      if (mounted) setState(() => _info = info);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final version = _info?['versionName']?.toString();
    final code = _info?['versionCode']?.toString();
    final flavor = _info?['flavor']?.toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, Insets.md),
      child: Column(
        children: [
          AppWordmark(size: 26, subtitle: strings.tagline.toUpperCase()),
          const SizedBox(height: Insets.sm),
          if (version == null)
            const Skeleton(width: 140, height: 12)
          else
            MonoText(
              'v$version${code == null ? '' : ' ($code)'}'
              '${flavor == null ? '' : ' · $flavor'}',
              style: context.texts.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: Insets.xs),
          Text(
            'Runs entirely on-device. No account, no network calls, no analytics.',
            textAlign: TextAlign.center,
            style: context.texts.bodySmall?.copyWith(
              color: context.scheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
