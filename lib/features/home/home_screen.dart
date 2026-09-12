import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/models/info_field.dart';
import '../../core/models/launcher.dart';
import '../../core/models/monitor.dart';
import '../../core/models/tier.dart';
import '../../core/state/services.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/util/formatters.dart';
import '../../data/launcher_catalog.dart';
import '../../data/toggle_catalog.dart';
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

/// G1/G4 — the landing screen: what device this is, what DevAccess can do to it right now,
/// live vitals, pinned launchers and the developer-options state (FR-QA-3).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;
  MonitorSample? _sample;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
      _loadIdentity();
    });
    // The home vitals refresh on a slow cadence; the monitor screen owns the fast stream.
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // NFR-PERF-2 — stop polling while another tab is in front.
    _visible = TabVisibility.of(context);
  }

  /// The hero names the device, so those two sections load whether or not the user has
  /// pinned them to the dashboard.
  Future<void> _loadIdentity() async {
    final info = Services.read(context).info;
    await info.loadIndex();
    await info.loadSection('device');
    await info.loadSection('os');
  }

  Future<void> _refresh() async {
    if (!mounted || !_visible) return;
    final sample = await Services.read(context).monitor.snapshot();
    if (mounted) setState(() => _sample = sample);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);

    return Scaffold(
      body: RefreshIndicator(
        edgeOffset: MediaQuery.paddingOf(context).top + 60,
        onRefresh: () async {
          await services.tier.refresh();
          await services.toggles.refreshAll();
          await services.info.loadSection('device', force: true);
          await services.info.loadSection('os', force: true);
          await _refresh();
        },
        child: ListenableBuilder(
          listenable: Listenable.merge([
            services.tier,
            services.toggles,
            services.settings,
            services.info,
          ]),
          builder: (context, _) => CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                title: const AppWordmark(size: 26),
                titleSpacing: Insets.gutter,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.description_outlined),
                    tooltip: strings.reportTitle,
                    onPressed: () => pushScreen(context, const ReportScreen()),
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune_rounded),
                    tooltip: strings.settingsTitle,
                    onPressed: () => pushScreen(context, const SettingsScreen()),
                  ),
                  const SizedBox(width: Insets.xxs),
                ],
              ),
              SliverList.list(
                children: [
                  FadeIn(child: _Hero(onOpenTier: () => pushScreen(context, const TierScreen()))),
                  FadeIn(index: 1, child: const _DeveloperState()),
                  FadeIn(
                    index: 2,
                    child: SectionHeader(
                      strings.monitorTitle,
                      icon: Icons.monitor_heart_outlined,
                      trailing: TextButton(
                        onPressed: () => pushScreen(context, const MonitorScreen()),
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                  FadeIn(index: 2, child: _Vitals(sample: _sample)),
                  FadeIn(index: 3, child: _QuickActions(onRefresh: _refresh)),
                  const FadeIn(index: 4, child: _Favourites()),
                  const FadeIn(index: 5, child: _PinnedSections()),
                  const SizedBox(height: Insets.scrollBottom),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reads one loaded info field, or null when the section has not arrived or the OS
/// withheld the value.
String? _infoValue(Services services, String sectionId, String key) {
  final section = services.info.section(sectionId);
  if (section == null) return null;
  for (final field in section.fields) {
    if (field.key == key) {
      return field.status == FieldStatus.ok ? field.displayValue : null;
    }
  }
  return null;
}

/// The identity block: which device this is, and what DevAccess is allowed to do to it.
class _Hero extends StatelessWidget {
  const _Hero({required this.onOpenTier});

  final VoidCallback onOpenTier;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);
    final scheme = context.scheme;
    final palette = context.palette;
    final status = services.tier.status;
    final tier = status.tier;

    final model = _infoValue(services, 'device', 'model');
    final maker = _infoValue(services, 'device', 'manufacturer');
    final release = _infoValue(services, 'os', 'release');
    final sdk = _infoValue(services, 'os', 'sdkInt');
    final soc = _infoValue(services, 'device', 'socModel');

    final tierColour = switch (tier) {
      AccessTier.t0 => scheme.onSurfaceVariant,
      AccessTier.t1 => palette.info,
      AccessTier.t2 => palette.success,
      AccessTier.t3 => palette.warning,
    };

    final subtitleParts = <String>[
      if (release != null) 'Android $release',
      if (sdk != null) 'API $sdk',
      ?soc,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xs, Insets.gutter, Insets.xxs),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: Corners.rXl,
          border: Border.all(color: palette.hairline),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.heroTop, palette.heroBottom],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: Corners.rXl,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpenTier,
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.tagline.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: Insets.xs),
                            if (model == null)
                              const Skeleton(width: 180, height: 26, radius: Corners.xs)
                            else
                              Text(
                                maker == null ? model : '$maker $model',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.headlineSmall?.copyWith(fontSize: 25),
                              ),
                            const SizedBox(height: Insets.xxs),
                            if (subtitleParts.isEmpty)
                              const Skeleton(width: 130, height: 13)
                            else
                              Text(
                                subtitleParts.join('  ·  '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  Wrap(
                    spacing: Insets.xs,
                    runSpacing: Insets.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Pill(
                        '${tier.code} · ${tier.title}',
                        colour: tierColour,
                        icon: tier == AccessTier.t0
                            ? Icons.lock_outline_rounded
                            : Icons.verified_user_outlined,
                      ),
                      if (status.flavor != 'play')
                        Pill(status.flavor.toUpperCase(), colour: palette.info),
                      if (tier == AccessTier.t0)
                        TextButton.icon(
                          onPressed: onOpenTier,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
                          ),
                          icon: const Icon(Icons.lock_open_outlined, size: 16),
                          label: Text(strings.unlockT2),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// FR-QA-3 — whether developer options and USB debugging are on right now.
class _DeveloperState extends StatelessWidget {
  const _DeveloperState();

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    final devOptions = services.toggles.value('development_settings_enabled');
    final adb = services.toggles.value('adb_enabled');

    return AppCard(
      padding: const EdgeInsets.fromLTRB(Insets.md, Insets.sm, Insets.sm, Insets.sm),
      child: Column(
        children: [
          _StateRow(
            label: 'Developer options',
            on: devOptions?.isSet == true ? devOptions!.on : null,
            reason: devOptions?.reason,
          ),
          Divider(height: Insets.lg, color: context.palette.hairline),
          _StateRow(
            label: 'USB debugging',
            on: adb?.isSet == true ? adb!.on : null,
            reason: adb?.reason,
          ),
          const SizedBox(height: Insets.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => _launch(context, 'dev_options'),
              icon: const Icon(Icons.developer_mode, size: 18),
              label: const Text('Open developer options'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launch(BuildContext context, String id) async {
    final spec = LauncherCatalog.byId(id);
    if (spec == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final strings = AppStrings.of(context);
    final result = await Services.read(context).bridge.launchChain(spec.chainMaps);
    if (result['ok'] != true) {
      messenger.showSnackBar(SnackBar(content: Text(strings.launchFailed)));
    }
  }
}

class _StateRow extends StatelessWidget {
  const _StateRow({required this.label, required this.on, this.reason});

  final String label;
  final bool? on;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = context.scheme;
    final colour = switch (on) {
      true => palette.success,
      false => scheme.onSurfaceVariant,
      null => palette.warning,
    };

    return Semantics(
      label: '$label ${on == true ? 'on' : on == false ? 'off' : 'unknown'}',
      child: Row(
        children: [
          StatusDot(colour: colour, live: on == true, size: 9),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.texts.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    )),
                if (on == null && reason != null)
                  Text(
                    reason!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          Text(
            on == true ? 'On' : (on == false ? 'Off' : Fmt.dash),
            style: context.texts.labelLarge?.copyWith(color: colour),
          ),
        ],
      ),
    );
  }
}

class _Vitals extends StatelessWidget {
  const _Vitals({required this.sample});

  final MonitorSample? sample;

  @override
  Widget build(BuildContext context) {
    final settings = Services.of(context).settings;
    final palette = context.palette;
    final s = sample;

    // Battery reads the other way round to the load meters: low is the bad end.
    final batteryColour = s?.batteryLevel == null
        ? palette.info
        : palette.forLoad(1 - (s!.batteryLevel! / 100));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: GridView.count(
        crossAxisCount: MediaQuery.sizeOf(context).width >= 600 ? 4 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: Insets.sm,
        crossAxisSpacing: Insets.sm,
        childAspectRatio: 1.42,
        children: [
          StatTile(
            label: 'Battery',
            icon: Icons.battery_charging_full_rounded,
            colour: batteryColour,
            value: s?.batteryLevel == null ? Fmt.dash : '${s!.batteryLevel}%',
            detail: s == null
                ? null
                : '${s.batteryStatus} · ${Fmt.temperature(s.batteryTempC, settings.temperatureUnit)}',
            progress: s?.batteryLevel == null ? null : s!.batteryLevel! / 100,
          ),
          StatTile(
            label: 'Memory',
            icon: Icons.memory_rounded,
            colour: palette.forLoad(s?.memFraction),
            value: s == null ? Fmt.dash : Fmt.bytes(s.memUsed, unit: settings.byteUnit),
            detail:
                s == null ? null : 'of ${Fmt.bytes(s.memTotal, unit: settings.byteUnit)} used',
            progress: s?.memFraction,
          ),
          StatTile(
            label: 'CPU',
            icon: Icons.developer_board_rounded,
            colour: palette.forLoad(s?.cpuLoad == null ? null : s!.cpuLoad! / 100),
            value: s?.cpuLoad == null ? Fmt.dash : Fmt.percent(s!.cpuLoad),
            detail: s == null
                ? null
                : '${s.coreCount} cores'
                    '${s.cpuLoadReadable ? '' : ' · load restricted'}',
            progress: s?.cpuLoad == null ? null : s!.cpuLoad! / 100,
          ),
          StatTile(
            label: 'Thermal',
            icon: Icons.thermostat_rounded,
            colour: _thermalColour(context, s?.thermalStatus),
            value: s?.thermalStatus ?? Fmt.dash,
            detail: s?.hottestZone == null
                ? null
                : 'hottest ${Fmt.temperature(s!.hottestZone, settings.temperatureUnit)}',
          ),
        ],
      ),
    );
  }

  /// Android reports thermal status as a word; map the escalating ones onto the palette so
  /// a throttling device is obvious at a glance.
  Color _thermalColour(BuildContext context, String? status) {
    final palette = context.palette;
    return switch (status?.toLowerCase()) {
      null || 'none' || 'light' => palette.success,
      'moderate' => palette.warning,
      'severe' || 'critical' || 'emergency' || 'shutdown' => palette.danger,
      _ => palette.info,
    };
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);
    final canAnimate = services.toggles.canWrite(ToggleCatalog.animationScales.first);
    final animationsOff = services.toggles.animationsOff;

    final actions = <_QuickAction>[
      _QuickAction(
        icon: animationsOff ? Icons.play_arrow_rounded : Icons.speed_rounded,
        label: animationsOff ? strings.restoreAnimations : strings.killAnimations,
        highlight: animationsOff,
        onTap: canAnimate
            ? () async {
                await services.toggles.setAllAnimationScales(animationsOff ? '1.0' : '0.0');
                await onRefresh();
              }
            : null,
      ),
      _QuickAction(
        icon: Icons.sensors_rounded,
        label: strings.sensorsTitle,
        onTap: () => pushScreen(context, const SensorsScreen()),
      ),
      _QuickAction(
        icon: Icons.lan_outlined,
        label: strings.networkTitle,
        onTap: () => pushScreen(context, const NetworkScreen()),
      ),
      _QuickAction(
        icon: Icons.apps_rounded,
        label: strings.appsTitle,
        onTap: () => pushScreen(context, const AppsScreen()),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Quick actions', icon: Icons.bolt_rounded),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 560 ? 4 : 2;
              final width =
                  (constraints.maxWidth - (Insets.sm * (columns - 1))) / columns;
              return Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                children: [
                  for (final action in actions)
                    SizedBox(width: width, child: action),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final enabled = onTap != null;
    final accent = highlight ? context.palette.warning : scheme.primary;

    return Material(
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: Corners.rMd,
        side: BorderSide(
          color: highlight ? accent.withValues(alpha: 0.45) : context.palette.hairline,
        ),
      ),
      child: InkWell(
        borderRadius: Corners.rMd,
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: accent),
                const SizedBox(height: Insets.sm),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelLarge?.copyWith(height: 1.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Favourites extends StatelessWidget {
  const _Favourites();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);
    final favourites = services.settings.favouriteLaunchers
        .map(LauncherCatalog.byId)
        .whereType<LauncherSpec>()
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          strings.favourites,
          icon: Icons.push_pin_outlined,
          trailing: favourites.isEmpty
              ? null
              : TextButton(
                  onPressed: () => pushScreen(context, const SettingsScreen()),
                  child: const Text('Manage'),
                ),
        ),
        if (favourites.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, 0),
            child: Text(
              strings.noFavourites,
              style: context.texts.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            child: Wrap(
              spacing: Insets.xs,
              runSpacing: Insets.xs,
              children: [
                for (final spec in favourites)
                  ActionChip(
                    avatar: Icon(spec.icon, size: 18),
                    label: Text(spec.label),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final result =
                          await Services.read(context).bridge.launchChain(spec.chainMaps);
                      if (result['ok'] != true) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(strings.launchFailed)),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// FR-SET-2 — the info sections the user chose to surface on the home dashboard.
class _PinnedSections extends StatefulWidget {
  const _PinnedSections();

  @override
  State<_PinnedSections> createState() => _PinnedSectionsState();
}

class _PinnedSectionsState extends State<_PinnedSections> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final services = Services.read(context);
    await services.info.loadIndex();
    for (final id in services.settings.dashboardSections) {
      if (!mounted) return;
      await services.info.loadSection(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([services.info, services.settings]),
      builder: (context, _) {
        final ids = services.settings.dashboardSections;
        if (ids.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              'Device',
              icon: Icons.smartphone_outlined,
              trailing: TextButton(
                onPressed: () => pushScreen(context, const SettingsScreen()),
                child: const Text('Choose'),
              ),
            ),
            for (final id in ids)
              if (services.info.section(id) case final section?)
                _PinnedCard(section: section),
          ],
        );
      },
    );
  }
}

class _PinnedCard extends StatelessWidget {
  const _PinnedCard({required this.section});

  final InfoSection section;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final rows = section.fields.where((f) => f.isOk).take(5).toList(growable: false);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(Insets.md, Insets.sm, Insets.md, Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  section.title,
                  style: context.texts.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              if (!section.isLoaded)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: Insets.xs),
          // A compact preview; the Device tab has the full, copyable list.
          if (!section.isLoaded)
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 220),
                SizedBox(height: Insets.xs),
                Skeleton(width: 170),
              ],
            )
          else
            for (final field in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 128,
                      child: Text(
                        field.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.xs),
                    Expanded(
                      child: Text(
                        field.displayValue,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: context.texts.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
