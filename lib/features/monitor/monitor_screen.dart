import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/models/monitor.dart';
import '../../core/platform/channels.dart';
import '../../core/state/services.dart';
import '../../core/util/formatters.dart';
import '../../widgets/common.dart';
import '../../widgets/sparkline.dart';

/// FR-MON-1..7 — the live dashboard.
///
/// The stream starts when this screen mounts and stops when it is dismissed, unless the
/// user has explicitly started the background service (FR-MON-7).
class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final services = Services.read(context);
      services.monitor.addViewer(services.settings.samplingIntervalMs);
      services.monitor.refreshServiceState();
    });
  }

  @override
  void deactivate() {
    Services.read(context).monitor.removeViewer();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.monitorTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.timeline),
            tooltip: 'Clear history',
            onPressed: () => services.monitor.clearHistory(),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([services.monitor, services.settings]),
        builder: (context, _) {
          final monitor = services.monitor;
          final sample = monitor.latest;
          if (sample == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const _SamplingCard(),
              _CpuCard(sample: sample),
              _MemoryCard(sample: sample),
              _BatteryCard(sample: sample),
              _ThermalCard(sample: sample),
              _NetworkCard(sample: sample),
              const _OverlayCard(),
            ],
          );
        },
      ),
    );
  }
}

/// FR-MON-7 — sampling rate, the battery-impact note and the foreground service switch.
class _SamplingCard extends StatelessWidget {
  const _SamplingCard();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);
    final settings = services.settings;
    final monitor = services.monitor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${strings.samplingInterval}: '
                      '${settings.samplingIntervalMs} ms'),
                ),
                Pill(
                  monitor.streaming ? 'streaming' : 'paused',
                  colour: monitor.streaming
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
              ],
            ),
            Slider(
              value: settings.samplingIntervalMs.toDouble(),
              min: 250,
              max: 5000,
              divisions: 19,
              label: '${settings.samplingIntervalMs} ms',
              onChanged: (v) => settings.setSamplingInterval(v.round()),
              onChangeEnd: (v) => monitor.setInterval(v.round()),
            ),
            Text(strings.persistentNote,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () async {
                    if (monitor.serviceRunning) {
                      await monitor.stopService();
                      return;
                    }
                    // FR-PERM-1 — ask for notifications right before the service needs them.
                    await services.bridge
                        .requestPermissions([AndroidPermissions.postNotifications]);
                    await monitor.startService();
                  },
                  icon: Icon(monitor.serviceRunning ? Icons.stop : Icons.play_arrow),
                  label: Text(monitor.serviceRunning
                      ? strings.stopPersistent
                      : strings.startPersistent),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.widgets_outlined),
                  tooltip: 'Refresh home-screen widgets',
                  onPressed: () => services.bridge.refreshWidgets(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CpuCard extends StatelessWidget {
  const _CpuCard({required this.sample});

  final MonitorSample sample;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final monitor = Services.of(context).monitor;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.developer_board, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(strings.cpu, style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(
                  sample.cpuLoad == null ? Fmt.dash : Fmt.percent(sample.cpuLoad),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Sparkline(
              values: monitor.cpuHistory.values,
              maxValue: 100,
              label: strings.cpu,
            ),
            const SizedBox(height: 6),
            Text(
              '${sample.coreCount} cores'
              '${sample.governor == null ? '' : ' · governor ${sample.governor}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!sample.cpuLoadReadable)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Per-core load is unavailable: /proc/stat is not readable by unprivileged '
                  'apps on this build.',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 10),
            for (final core in sample.cores)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 46,
                      child: Text('cpu${core.index}',
                          style: Theme.of(context).textTheme.labelSmall),
                    ),
                    Expanded(
                      child: MeterBar(
                        fraction: core.load != null
                            ? core.load! / 100
                            : (core.frequencyFraction ?? 0),
                        colour: core.online ? scheme.primary : scheme.outline,
                        label: 'core ${core.index}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 92,
                      child: Text(
                        core.load != null
                            ? Fmt.percent(core.load)
                            : Fmt.frequency(core.currentKHz),
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            if (!sample.cpuFreqReadable && sample.cores.isEmpty)
              Text(
                'cpufreq nodes are not readable on this build, so per-core frequency is '
                'unavailable.',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.sample});

  final MonitorSample sample;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);
    final unit = services.settings.byteUnit;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(strings.memory, style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                if (sample.lowMemory)
                  Pill('low memory', colour: scheme.error, icon: Icons.warning_amber),
              ],
            ),
            const SizedBox(height: 8),
            Sparkline(
              values: services.monitor.memoryHistory.values,
              maxValue: 100,
              colour: scheme.tertiary,
              label: strings.memory,
            ),
            const SizedBox(height: 10),
            _row(context, 'Used', Fmt.bytes(sample.memUsed, unit: unit)),
            _row(context, 'Available', Fmt.bytes(sample.memAvailable, unit: unit)),
            _row(context, 'Total', Fmt.bytes(sample.memTotal, unit: unit)),
            _row(context, 'Low-memory threshold', Fmt.bytes(sample.memThreshold, unit: unit)),
            _row(
              context,
              'DevAccess PSS',
              sample.selfPssBytes >= 0 ? Fmt.bytes(sample.selfPssBytes, unit: unit) : Fmt.dash,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Theme.of(context).textTheme.bodySmall)),
            Text(v,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
          ],
        ),
      );
}

class _BatteryCard extends StatelessWidget {
  const _BatteryCard({required this.sample});

  final MonitorSample sample;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);
    final tempUnit = services.settings.temperatureUnit;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  sample.charging ? Icons.battery_charging_full : Icons.battery_full,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(strings.battery, style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(
                  sample.batteryLevel == null ? Fmt.dash : '${sample.batteryLevel}%',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Sparkline(
              values: services.monitor.batteryTempHistory.values,
              colour: scheme.error,
              label: 'battery temperature',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Pill(sample.batteryStatus, colour: scheme.primary),
                Pill(sample.batteryPlugged, colour: scheme.tertiary),
                Pill('health ${sample.batteryHealth}', colour: scheme.secondary),
              ],
            ),
            const SizedBox(height: 10),
            _row(context, 'Temperature', Fmt.temperature(sample.batteryTempC, tempUnit)),
            _row(
              context,
              'Voltage',
              sample.batteryVoltage == null
                  ? Fmt.dash
                  : '${sample.batteryVoltage!.toStringAsFixed(3)} V',
            ),
            _row(
              context,
              'Current',
              sample.batteryCurrentMa == null
                  ? '${Fmt.dash} (not exposed by this device)'
                  : '${sample.batteryCurrentMa!.toStringAsFixed(0)} mA',
            ),
            _row(
              context,
              sample.charging ? 'Estimated time to full' : 'Estimated time remaining',
              Fmt.minutes(sample.batteryEstimateMinutes),
            ),
            _row(
              context,
              'Observed rate',
              sample.batteryRatePerHour == null
                  ? '${Fmt.dash} (needs a level change)'
                  : '${sample.batteryRatePerHour!.toStringAsFixed(1)} %/h',
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(k, style: Theme.of(context).textTheme.bodySmall)),
            Text(v,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _ThermalCard extends StatelessWidget {
  const _ThermalCard({required this.sample});

  final MonitorSample sample;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final unit = Services.of(context).settings.temperatureUnit;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.thermostat, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(strings.thermal, style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Pill(
                  sample.thermalStatus,
                  colour: sample.thermalStatus == 'None' ? scheme.primary : scheme.error,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (sample.thermalZones.isEmpty)
              Text(
                sample.thermalReason ??
                    '/sys/class/thermal is not readable by unprivileged apps on this build.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              for (final zone in sample.thermalZones.take(20))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${zone.name} · ${zone.type}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                      Text(Fmt.temperature(zone.celsius, unit),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _NetworkCard extends StatelessWidget {
  const _NetworkCard({required this.sample});

  final MonitorSample sample;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);
    final unit = services.settings.byteUnit;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.swap_vert, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text('${strings.network} throughput',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            if (!sample.throughputSupported)
              Text('TrafficStats is not supported on this device.',
                  style: Theme.of(context).textTheme.bodySmall)
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('↓ ${Fmt.rate(sample.rxPerSec, unit: unit)}',
                            style: Theme.of(context).textTheme.titleSmall),
                        Sparkline(
                          values: services.monitor.rxHistory.values,
                          height: 34,
                          colour: scheme.primary,
                          label: 'download',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('↑ ${Fmt.rate(sample.txPerSec, unit: unit)}',
                            style: Theme.of(context).textTheme.titleSmall),
                        Sparkline(
                          values: services.monitor.txHistory.values,
                          height: 34,
                          colour: scheme.tertiary,
                          label: 'upload',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'DevAccess itself: ↓ ${Fmt.rate(sample.uidRxPerSec, unit: unit)} · '
                '↑ ${Fmt.rate(sample.uidTxPerSec, unit: unit)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// FR-MON-6 — the opt-in FPS / frame-time overlay.
class _OverlayCard extends StatelessWidget {
  const _OverlayCard();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);
    final monitor = services.monitor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(strings.fpsOverlay,
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                Switch(
                  value: monitor.overlayRunning,
                  onChanged: monitor.overlayGranted
                      ? (v) async {
                          final messenger = ScaffoldMessenger.of(context);
                          if (v) {
                            final error = await monitor.startOverlay();
                            if (error != null) {
                              messenger.showSnackBar(SnackBar(content: Text(error)));
                            }
                          } else {
                            await monitor.stopOverlay();
                          }
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(strings.fpsOverlayNote, style: Theme.of(context).textTheme.bodySmall),
            if (!monitor.overlayGranted) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  await monitor.requestOverlayPermission();
                  await monitor.refreshServiceState();
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(strings.grantOverlay),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
