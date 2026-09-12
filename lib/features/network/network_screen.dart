import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/platform/channels.dart';
import '../../core/state/services.dart';
import '../../core/util/formatters.dart';
import '../../data/launcher_catalog.dart';
import '../../widgets/common.dart';

/// FR-NET-1..5 — connection state, Wi-Fi and cellular detail, the tool bench and the
/// connectivity launchers.
class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  Map<String, dynamic> _status = const {};
  Map<String, dynamic> _wifi = const {};
  Map<String, dynamic> _telephony = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final bridge = Services.read(context).bridge;
    final results = await Future.wait([
      bridge.netStatus(),
      bridge.wifiInfo(),
      bridge.telephonyInfo(),
    ]);
    if (!mounted) return;
    setState(() {
      _status = results[0];
      _wifi = results[1];
      _telephony = results[2];
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.networkTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: strings.refresh,
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: strings.connection),
            Tab(text: strings.wifiDetails),
            Tab(text: strings.tools),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _ConnectionTab(status: _status, telephony: _telephony),
                _WifiTab(wifi: _wifi, onGranted: _refresh),
                const NetToolsTab(),
              ],
            ),
    );
  }
}

class _ConnectionTab extends StatelessWidget {
  const _ConnectionTab({required this.status, required this.telephony});

  final Map<String, dynamic> status;
  final Map<String, dynamic> telephony;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final transports =
        (status['transports'] as List?)?.map((e) => e.toString()).toList() ?? const [];

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      status['connected'] == true ? Icons.cloud_done : Icons.cloud_off,
                      color: status['connected'] == true ? scheme.primary : scheme.error,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      status['type']?.toString() ?? 'None',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Pill(
                      status['connected'] == true ? 'validated internet' : 'no validated internet',
                      colour: status['connected'] == true ? scheme.primary : scheme.error,
                    ),
                    Pill(status['metered'] == true ? 'metered' : 'unmetered',
                        colour: status['metered'] == true ? scheme.tertiary : scheme.primary),
                    if (status['vpn'] == true) Pill('VPN', colour: scheme.error),
                    if (status['roaming'] == true) Pill('roaming', colour: scheme.tertiary),
                    for (final t in transports) Pill(t, colour: scheme.secondary),
                  ],
                ),
              ],
            ),
          ),
        ),
        SectionHeader('Addresses'),
        Card(
          child: Column(
            children: [
              _kv(context, 'Interface', status['interface']?.toString()),
              _kv(context, 'IPv4', _list(status['ipv4'])),
              _kv(context, 'IPv6', _list(status['ipv6'])),
              _kv(context, 'Gateway', status['gateway']?.toString()),
              _kv(context, 'DNS', _list(status['dns'])),
              _kv(context, 'Search domains', status['domains']?.toString()),
              _kv(context, 'Private DNS', status['privateDns']?.toString()),
              _kv(context, 'MTU', status['mtu']?.toString()),
              _kv(
                context,
                'Reported bandwidth',
                '↓ ${status['downstreamKbps'] ?? Fmt.dash} kbps · '
                    '↑ ${status['upstreamKbps'] ?? Fmt.dash} kbps',
              ),
            ],
          ),
        ),
        SectionHeader(strings.cellularDetails),
        _TelephonyCard(telephony: telephony),
        SectionHeader('Settings'),
        const _NetworkLaunchers(),
      ],
    );
  }

  static String? _list(Object? v) {
    final list = v as List?;
    if (list == null || list.isEmpty) return null;
    return list.join(', ');
  }

  Widget _kv(BuildContext context, String k, String? v) => ListTile(
        dense: true,
        title: Text(k, style: Theme.of(context).textTheme.labelMedium),
        subtitle: SelectableText(v ?? Fmt.dash),
      );
}

/// FR-NET-3 — cellular detail, with READ_PHONE_STATE requested in context (FR-PERM-1).
class _TelephonyCard extends StatefulWidget {
  const _TelephonyCard({required this.telephony});

  final Map<String, dynamic> telephony;

  @override
  State<_TelephonyCard> createState() => _TelephonyCardState();
}

class _TelephonyCardState extends State<_TelephonyCard> {
  late Map<String, dynamic> _data = widget.telephony;

  @override
  Widget build(BuildContext context) {
    if (_data['available'] != true) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.signal_cellular_off),
          title: const Text('Telephony unavailable'),
          subtitle: Text(_data['reason']?.toString() ?? 'No telephony hardware'),
        ),
      );
    }

    final signal = _data['signalStrength'] as Map?;

    return Card(
      child: Column(
        children: [
          if (_data['phoneStateGranted'] != true)
            ListTile(
              leading: Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.tertiary),
              title: const Text('Some fields need READ_PHONE_STATE'),
              subtitle: const Text(
                'Network generation is permission-gated from Android 11 (API 30).',
              ),
              trailing: FilledButton(
                onPressed: () async {
                  final services = Services.read(context);
                  await services.bridge
                      .requestPermissions([AndroidPermissions.readPhoneState]);
                  final refreshed = await services.bridge.telephonyInfo();
                  if (mounted) setState(() => _data = refreshed);
                },
                child: Text(AppStrings.of(context).grant),
              ),
              isThreeLine: true,
            ),
          _kv(context, 'Carrier', _data['carrier']?.toString()),
          _kv(context, 'MCC/MNC', _data['mccMnc']?.toString()),
          _kv(context, 'SIM operator', _data['simOperator']?.toString()),
          _kv(context, 'SIM state', _data['simState']?.toString()),
          _kv(context, 'SIM slots', _data['simCount']?.toString()),
          _kv(context, 'Phone type', _data['phoneType']?.toString()),
          _kv(context, 'Roaming', _data['roaming'] == true ? 'Yes' : 'No'),
          _kv(
            context,
            'Network generation',
            _data['generation']?.toString() ?? _data['generationReason']?.toString(),
          ),
          _kv(context, 'Data state', _data['dataState']?.toString()),
          _kv(context, 'Data activity', _data['dataActivity']?.toString()),
          _kv(context, 'Signal', signal?['detail']?.toString()),
          _kv(context, 'IMEI / MEID', _data['imeiReason']?.toString()),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String? v) => ListTile(
        dense: true,
        title: Text(k, style: Theme.of(context).textTheme.labelMedium),
        subtitle: SelectableText(v ?? Fmt.dash),
      );
}

/// FR-NET-2 — Wi-Fi detail, with the C5 location requirement handled explicitly.
class _WifiTab extends StatelessWidget {
  const _WifiTab({required this.wifi, required this.onGranted});

  final Map<String, dynamic> wifi;
  final Future<void> Function() onGranted;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    if (wifi['available'] != true) {
      return EmptyState(
        icon: Icons.wifi_off,
        title: 'Wi-Fi details unavailable',
        message: wifi['reason']?.toString(),
      );
    }

    final needsLocation = wifi['locationGranted'] != true;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (needsLocation)
          Card(
            child: ListTile(
              leading: Icon(Icons.location_off, color: Theme.of(context).colorScheme.tertiary),
              title: Text(strings.grantLocationForSsid),
              subtitle: const Text(
                'Android hides the SSID and BSSID from apps without location permission '
                'since 8.1 (C5). Location services must also be switched on.',
              ),
              isThreeLine: true,
              trailing: FilledButton(
                onPressed: () async {
                  await Services.read(context).bridge.requestPermissions([
                    AndroidPermissions.fineLocation,
                    AndroidPermissions.coarseLocation,
                  ]);
                  await onGranted();
                },
                child: Text(strings.grant),
              ),
            ),
          ),
        Card(
          child: Column(
            children: [
              _kv(context, 'SSID', wifi['ssid']?.toString() ?? wifi['ssidReason']?.toString()),
              _kv(context, 'BSSID', wifi['bssid']?.toString() ?? wifi['bssidReason']?.toString()),
              _kv(context, 'RSSI',
                  wifi['rssi'] == null ? null : '${wifi['rssi']} dBm (level ${wifi['signalLevel']}/4)'),
              _kv(context, 'Link speed',
                  wifi['linkSpeed'] == null ? null : '${wifi['linkSpeed']} Mbps'),
              _kv(context, 'Tx / Rx link speed',
                  '${wifi['txLinkSpeed'] ?? Fmt.dash} / ${wifi['rxLinkSpeed'] ?? Fmt.dash} Mbps'),
              _kv(context, 'Frequency',
                  wifi['frequency'] == null ? null : '${wifi['frequency']} MHz'),
              _kv(context, 'Band', wifi['band']?.toString()),
              _kv(context, 'Channel', wifi['channel']?.toString()),
              _kv(context, 'Standard', wifi['standard']?.toString()),
              _kv(context, 'Hidden SSID', wifi['hiddenSsid'] == true ? 'Yes' : 'No'),
              _kv(
                context,
                'Randomised MAC',
                wifi['randomizedMac'] == null
                    ? 'Requires Android 11 (API 30)'
                    : (wifi['randomizedMac'] == true ? 'Yes' : 'No'),
              ),
              _kv(context, 'Device MAC', 'Restricted by OS since Android 6 (API 23)'),
              _kv(context, '5 GHz supported', wifi['5GhzSupported'] == true ? 'Yes' : 'No'),
              _kv(
                context,
                '6 GHz supported',
                wifi['6GhzSupported'] == null
                    ? 'Requires Android 11 (API 30)'
                    : (wifi['6GhzSupported'] == true ? 'Yes' : 'No'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String? v) => ListTile(
        dense: true,
        title: Text(k, style: Theme.of(context).textTheme.labelMedium),
        subtitle: SelectableText(v ?? Fmt.dash),
      );
}

/// FR-NET-5 — the connectivity launchers.
class _NetworkLaunchers extends StatelessWidget {
  const _NetworkLaunchers();

  static const _ids = ['wifi', 'mobile_data', 'vpn', 'hotspot', 'airplane', 'bluetooth'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final id in _ids)
            if (LauncherCatalog.byId(id) case final spec?)
              ActionChip(
                avatar: Icon(spec.icon, size: 18),
                label: Text(spec.label),
                onPressed: () =>
                    Services.read(context).bridge.launchChain(spec.chainMaps),
              ),
        ],
      ),
    );
  }
}

/// FR-NET-4 — ping, traceroute, DNS, reachability and the HTTP latency test.
class NetToolsTab extends StatefulWidget {
  const NetToolsTab({super.key});

  @override
  State<NetToolsTab> createState() => _NetToolsTabState();
}

class _NetToolsTabState extends State<NetToolsTab> {
  final _host = TextEditingController(text: 'one.one.one.one');
  final _url = TextEditingController(text: 'https://example.com');
  final _lines = <String>[];
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _running = false;
  String? _summary;

  @override
  void dispose() {
    _sub?.cancel();
    _host.dispose();
    _url.dispose();
    super.dispose();
  }

  void _startStream(String tool) {
    _sub?.cancel();
    setState(() {
      _lines.clear();
      _summary = null;
      _running = true;
    });
    final args = <String, dynamic>{
      'tool': tool,
      'host': _host.text.trim(),
      if (tool == 'ping') 'count': 5,
      if (tool == 'traceroute') 'maxHops': 20,
    };
    _sub = Services.read(context).bridge.netTool(args).listen(
      (event) {
        if (!mounted) return;
        setState(() {
          switch (event['type']) {
            case 'line':
              _lines.add(event['text'] as String? ?? '');
            case 'error':
              _lines.add('! ${event['text']}');
            case 'done':
              _summary = event['summary'] as String?;
              _running = false;
          }
        });
      },
      onError: (Object e) {
        if (mounted) {
          setState(() {
            _lines.add('! $e');
            _running = false;
          });
        }
      },
      onDone: () {
        if (mounted) setState(() => _running = false);
      },
    );
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    setState(() => _running = false);
  }

  Future<void> _runOneShot(Future<Map<String, dynamic>> Function() call, String title) async {
    setState(() {
      _lines
        ..clear()
        ..add('> $title');
      _summary = null;
      _running = true;
    });
    final result = await call();
    if (!mounted) return;
    setState(() {
      _running = false;
      if (result['ok'] == true) {
        result.forEach((k, v) {
          if (k == 'ok') return;
          if (k == 'addresses' && v is List) {
            for (final a in v) {
              final m = (a as Map).map((k2, v2) => MapEntry(k2.toString(), v2));
              _lines.add('  ${m['address']}  (${m['family']})');
            }
            return;
          }
          _lines.add('  ${k.padRight(14)} $v');
        });
        _summary = 'Completed';
      } else {
        _lines.add('  ${result['error'] ?? 'failed'}');
        _summary = 'Failed';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final bridge = Services.of(context).bridge;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        TextField(
          controller: _host,
          decoration: InputDecoration(labelText: strings.host, hintText: 'example.com'),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: _running ? null : () => _startStream('ping'),
              child: Text(strings.ping),
            ),
            FilledButton.tonal(
              onPressed: _running ? null : () => _startStream('traceroute'),
              child: Text(strings.traceroute),
            ),
            FilledButton.tonal(
              onPressed: _running
                  ? null
                  : () => _runOneShot(
                        () => bridge.dnsLookup(_host.text.trim()),
                        'dns ${_host.text.trim()}',
                      ),
              child: Text(strings.dnsLookup),
            ),
            FilledButton.tonal(
              onPressed: _running
                  ? null
                  : () => _runOneShot(
                        () => bridge.reachability(_host.text.trim(), 443),
                        'connect ${_host.text.trim()}:443',
                      ),
              child: Text(strings.reachability),
            ),
            if (_running)
              OutlinedButton.icon(
                onPressed: _stop,
                icon: const Icon(Icons.stop, size: 18),
                label: Text(strings.stop),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _url,
          decoration: InputDecoration(labelText: 'URL', hintText: 'https://example.com'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            FilledButton.tonal(
              onPressed: _running
                  ? null
                  : () => _runOneShot(
                        () => bridge.httpTest(_url.text.trim()),
                        'http GET ${_url.text.trim()}',
                      ),
              child: Text(strings.httpTest),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Uses mobile data if that is the active network.',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_running) const LinearProgressIndicator(),
        if (_lines.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    _lines.join('\n'),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  if (_summary != null) ...[
                    const Divider(height: 20),
                    Text(_summary!, style: Theme.of(context).textTheme.labelMedium),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
