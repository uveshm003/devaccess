import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/models/sensor.dart';
import '../../core/state/monitor_controller.dart';
import '../../core/state/services.dart';
import '../../core/util/formatters.dart';
import '../../widgets/common.dart';
import '../../widgets/sparkline.dart';
import '../shell/app_shell.dart';

/// FR-SEN-1 — the sensor catalogue with full metadata.
class SensorsScreen extends StatefulWidget {
  const SensorsScreen({super.key});

  @override
  State<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends State<SensorsScreen> {
  final _search = TextEditingController();
  String _query = '';
  List<SensorInfo>? _sensors;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final raw = await Services.read(context).bridge.sensors();
    if (!mounted) return;
    setState(() => _sensors = raw.map(SensorInfo.fromMap).toList(growable: false));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final sensors = _sensors;

    return Scaffold(
      appBar: AppBar(title: Text(strings.sensorsTitle)),
      body: sensors == null
          ? const Center(child: CircularProgressIndicator())
          : sensors.isEmpty
              ? const EmptyState(
                  icon: Icons.sensors_off,
                  title: 'No sensors reported',
                  message: 'This device exposes no sensors to apps, or SensorManager is '
                      'unavailable.',
                )
              : Column(
                  children: [
                    SearchBox(
                      hint: strings.search,
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 32),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                            child: Text(
                              '${sensors.length} sensors · '
                              '${sensors.where((s) => s.wakeUp).length} wake-up',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          for (final sensor
                              in sensors.where((s) => s.matches(_query)))
                            _SensorTile(sensor: sensor),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _SensorTile extends StatelessWidget {
  const _SensorTile({required this.sensor});

  final SensorInfo sensor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(_iconFor(sensor.type), color: scheme.primary),
        title: Text(sensor.typeName),
        subtitle: Text(
          '${sensor.name}\n${sensor.vendor} · v${sensor.version} · '
          '${sensor.reportingMode}${sensor.wakeUp ? ' · wake-up' : ''}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => pushScreen(context, SensorDetailScreen(sensor: sensor)),
      ),
    );
  }

  static IconData _iconFor(int type) => switch (type) {
        1 => Icons.vibration,
        2 => Icons.explore_outlined,
        4 => Icons.threesixty,
        5 => Icons.light_mode_outlined,
        6 => Icons.compress,
        8 => Icons.social_distance_outlined,
        9 => Icons.arrow_downward,
        12 => Icons.water_drop_outlined,
        13 => Icons.thermostat_outlined,
        18 || 19 => Icons.directions_walk,
        21 => Icons.favorite_outline,
        _ => Icons.sensors,
      };
}

/// FR-SEN-2 / FR-SEN-3 — live values with a rolling graph, plus the self-test runner.
class SensorDetailScreen extends StatefulWidget {
  const SensorDetailScreen({required this.sensor, super.key});

  final SensorInfo sensor;

  @override
  State<SensorDetailScreen> createState() => _SensorDetailScreenState();
}

class _SensorDetailScreenState extends State<SensorDetailScreen> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  SensorReading? _reading;
  String? _error;
  final _history = SeriesBuffer(90);

  // Self-test state.
  bool _testing = false;
  int _remaining = 0;
  Timer? _testTimer;
  double? _testMin;
  double? _testMax;
  bool? _testPassed;

  @override
  void initState() {
    super.initState();
    if (widget.sensor.streamable) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
    }
  }

  void _listen() {
    final services = Services.read(context);
    _sub = services.bridge
        .sensorStream(widget.sensor.type, delayUs: 40000)
        .listen(
      (event) {
        if (event['values'] == null) return;
        final reading = SensorReading.fromMap(event);
        if (!mounted) return;
        setState(() {
          _reading = reading;
          _history.add(reading.magnitude);
          if (_testing) _recordTestSample(reading.magnitude);
        });
      },
      onError: (Object e) {
        if (mounted) setState(() => _error = e.toString());
      },
      cancelOnError: false,
    );
  }

  void _recordTestSample(double v) {
    _testMin = _testMin == null ? v : (v < _testMin! ? v : _testMin);
    _testMax = _testMax == null ? v : (v > _testMax! ? v : _testMax);
  }

  void _startTest() {
    final test = widget.sensor.selfTest;
    if (test == null) return;
    setState(() {
      _testing = true;
      _testMin = null;
      _testMax = null;
      _testPassed = null;
      _remaining = test.seconds;
    });
    _testTimer?.cancel();
    _testTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        _finishTest();
      }
    });
  }

  void _finishTest() {
    final test = widget.sensor.selfTest!;
    final min = _testMin, max = _testMax;
    final passed = switch (test.mode) {
      SelfTestMode.present => min != null,
      SelfTestMode.range || SelfTestMode.variance =>
        min != null && max != null && (max - min) >= test.threshold,
    };
    setState(() {
      _testing = false;
      _testPassed = passed;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _testTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final s = widget.sensor;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.typeName)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 10),
                  _meta(context, 'Vendor', s.vendor),
                  _meta(context, 'Type', '${s.type} · ${s.stringType}'),
                  _meta(context, 'Version', '${s.version}'),
                  _meta(context, 'Resolution', '${s.resolution} ${s.unit}'),
                  _meta(context, 'Maximum range', '${s.maxRange} ${s.unit}'),
                  _meta(context, 'Power draw', '${s.power} mA'),
                  _meta(context, 'Minimum delay',
                      '${s.minDelay} µs${s.maxHz == null ? '' : ' (${s.maxHz!.toStringAsFixed(0)} Hz max)'}'),
                  _meta(context, 'Maximum delay', '${s.maxDelay} µs'),
                  _meta(context, 'Reporting mode', s.reportingMode),
                  _meta(context, 'Wake-up sensor', s.wakeUp ? 'yes' : 'no'),
                  _meta(context, 'Dynamic sensor', s.dynamicSensor ? 'yes' : 'no'),
                  _meta(context, 'FIFO max events', '${s.fifoMax}'),
                ],
              ),
            ),
          ),
          SectionHeader(strings.liveViewer),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: !s.streamable
                  ? Text(strings.noStream, style: theme.textTheme.bodyMedium)
                  : _error != null
                      ? Text(_error!, style: theme.textTheme.bodyMedium)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_reading == null)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: LinearProgressIndicator(),
                              )
                            else ...[
                              for (var i = 0; i < _reading!.values.length; i++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 36,
                                        child: Text(
                                          i < s.axes.length ? s.axes[i] : 'v$i',
                                          style: theme.textTheme.labelMedium,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          '${_reading!.values[i].toStringAsFixed(4)} ${s.unit}',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontFeatures: const [FontFeature.tabularFigures()],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Text('Accuracy: ${_reading!.accuracyLabel}',
                                  style: theme.textTheme.bodySmall),
                              const SizedBox(height: 10),
                              Sparkline(values: _history.values, label: s.typeName),
                            ],
                          ],
                        ),
            ),
          ),
          if (s.selfTest != null) ...[
            SectionHeader(strings.selfTest),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.selfTest!.instruction, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    if (_testing) ...[
                      LinearProgressIndicator(
                        value: 1 - (_remaining / s.selfTest!.seconds),
                      ),
                      const SizedBox(height: 8),
                      Text('$_remaining s remaining · observed range '
                          '${_testMin?.toStringAsFixed(2) ?? Fmt.dash} → '
                          '${_testMax?.toStringAsFixed(2) ?? Fmt.dash}'),
                    ] else
                      FilledButton.tonalIcon(
                        onPressed: _startTest,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(strings.startTest),
                      ),
                    if (_testPassed != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            _testPassed! ? Icons.check_circle : Icons.help_outline,
                            color: _testPassed!
                                ? theme.colorScheme.primary
                                : theme.colorScheme.tertiary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _testPassed! ? strings.testPassed : strings.testInconclusive,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Observed range: ${_testMin?.toStringAsFixed(3) ?? Fmt.dash} → '
                        '${_testMax?.toStringAsFixed(3) ?? Fmt.dash} ${s.unit} '
                        '(needed ≥ ${s.selfTest!.threshold})',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _meta(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(k,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
            ),
            Expanded(child: SelectableText(v, style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      );
}
