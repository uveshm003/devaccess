import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/models/app_entry.dart';
import '../../core/state/services.dart';
import '../../core/util/formatters.dart';
import '../../widgets/common.dart';

/// FR-APP-1..3 — the apps inspector.
///
/// C6 — the Play build lists launchable packages only; the full listing is a foss-flavour
/// capability and is presented as such rather than silently missing.
class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _showAll = false;
  bool _loading = true;
  List<AppEntry> _apps = const [];
  bool _canListAll = false;
  String? _allReason;
  final Map<String, Uint8List?> _icons = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await Services.read(context).bridge.appsList(all: _showAll);
    if (!mounted) return;
    setState(() {
      _apps = (result['apps'] as List?)
              ?.whereType<Map>()
              .map((e) => AppEntry.fromMap(e.map((k, v) => MapEntry(k.toString(), v))))
              .toList(growable: false) ??
          const [];
      _canListAll = result['canListAll'] == true;
      _allReason = result['allReason'] as String?;
      _loading = false;
    });
  }

  Future<Uint8List?> _icon(String package) async {
    if (_icons.containsKey(package)) return _icons[package];
    final bytes = await Services.read(context).bridge.appIcon(package);
    if (mounted) setState(() => _icons[package] = bytes);
    return bytes;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final visible = _apps.where((a) => a.matches(_query)).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: strings.refresh,
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          SearchBox(
            hint: strings.searchApps,
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
          ),
          SwitchListTile(
            value: _showAll,
            title: Text(strings.showAllPackages),
            subtitle: Text(
              _canListAll
                  ? 'Includes system and non-launchable packages.'
                  : _allReason ?? 'Not available in this build.',
            ),
            isThreeLine: !_canListAll,
            onChanged: _canListAll
                ? (v) {
                    setState(() => _showAll = v);
                    _load();
                  }
                : null,
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (visible.isEmpty)
            Expanded(
              child: EmptyState(
                icon: Icons.apps_outage,
                title: 'No apps matched',
                message: _query.isEmpty
                    ? 'Nothing was returned by the package manager.'
                    : 'Nothing matches "$_query".',
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: visible.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _AppRow(
                  app: visible[i],
                  iconLoader: _icon,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.iconLoader});

  final AppEntry app;
  final Future<Uint8List?> Function(String) iconLoader;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: SizedBox(
        width: 40,
        height: 40,
        child: FutureBuilder<Uint8List?>(
          future: iconLoader(app.package),
          builder: (context, snapshot) => snapshot.data == null
              ? Icon(Icons.android, color: scheme.onSurfaceVariant)
              : Image.memory(snapshot.data!, gaplessPlayback: true),
        ),
      ),
      title: Text(app.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${app.package}\n'
        'v${app.versionName ?? '?'} (${app.versionCode}) · target ${app.targetSdk}'
        '${app.minSdk == null ? '' : ' · min ${app.minSdk}'}',
        maxLines: 2,
      ),
      isThreeLine: true,
      trailing: Wrap(
        spacing: 4,
        children: [
          if (app.debuggable) Pill('debug', colour: scheme.error),
          if (app.system) Pill('system', colour: scheme.tertiary),
        ],
      ),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _AppSheet(app: app),
      ),
    );
  }
}

/// FR-APP-2 — per-app quick actions, all delegated to the OS through intents.
class _AppSheet extends StatefulWidget {
  const _AppSheet({required this.app});

  final AppEntry app;

  @override
  State<_AppSheet> createState() => _AppSheetState();
}

class _AppSheetState extends State<_AppSheet> {
  List<Map<String, dynamic>>? _permissions;
  String? _permissionsError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPermissions());
  }

  Future<void> _loadPermissions() async {
    final result =
        await Services.read(context).bridge.appPermissions(widget.app.package);
    if (!mounted) return;
    setState(() {
      if (result['ok'] == true) {
        _permissions = (result['permissions'] as List?)
                ?.whereType<Map>()
                .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
                .toList(growable: false) ??
            const [];
      } else {
        _permissionsError = result['error'] as String? ?? 'Unavailable';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final app = widget.app;
    final bridge = Services.of(context).bridge;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(app.label, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          SelectableText(app.package,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => bridge.openAppScreen(app.package, 'details'),
                icon: const Icon(Icons.info_outline, size: 18),
                label: Text(strings.appDetails),
              ),
              OutlinedButton.icon(
                onPressed: () => bridge.openAppScreen(app.package, 'permissions'),
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: Text(strings.permissions),
              ),
              OutlinedButton.icon(
                onPressed: () => bridge.openAppScreen(app.package, 'notifications'),
                icon: const Icon(Icons.notifications_outlined, size: 18),
                label: const Text('Notifications'),
              ),
              if (app.launchable)
                OutlinedButton.icon(
                  onPressed: () => bridge.openAppScreen(app.package, 'launch'),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(strings.openApp),
                ),
              if (!app.system)
                OutlinedButton.icon(
                  onPressed: () => bridge.openAppScreen(app.package, 'uninstall'),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(strings.uninstall),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Clearing data and uninstalling are handled by Android itself — DevAccess only '
            'opens the right screen (FR-APP-2).',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const Divider(height: 28),
          _kv(context, 'Version', '${app.versionName ?? '?'} (${app.versionCode})'),
          _kv(context, 'Target SDK', '${app.targetSdk}'),
          _kv(context, 'Minimum SDK', app.minSdk?.toString() ?? Fmt.dash),
          _kv(context, 'Install source', app.installSource),
          _kv(context, 'First installed', Fmt.timestamp(app.firstInstall)),
          _kv(context, 'Last updated', Fmt.timestamp(app.lastUpdate)),
          _kv(context, 'UID', '${app.uid}'),
          _kv(context, 'Debuggable', app.debuggable ? 'Yes' : 'No'),
          _kv(context, 'System app', app.system ? 'Yes' : 'No'),
          _kv(context, 'Enabled', app.enabled ? 'Yes' : 'No'),
          const Divider(height: 28),
          Text('${strings.permissions} (declared)',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_permissionsError != null)
            Text(_permissionsError!, style: Theme.of(context).textTheme.bodySmall)
          else if (_permissions == null)
            const LinearProgressIndicator()
          else if (_permissions!.isEmpty)
            Text('None declared', style: Theme.of(context).textTheme.bodySmall)
          else
            for (final p in _permissions!)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      p['granted'] == true ? Icons.check_circle_outline : Icons.circle_outlined,
                      size: 15,
                      color: p['granted'] == true
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (p['name'] as String? ?? '').replaceFirst('android.permission.', ''),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
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
