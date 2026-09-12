import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/strings.dart';
import '../../core/models/info_field.dart';
import '../../core/state/services.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/copyable_field.dart';
import '../report/report_screen.dart';
import '../shell/app_shell.dart';

/// FR-INFO-1..6 — the device information dashboard.
///
/// NFR-PERF-1 — sections stream in one at a time. FR-INFO-4 — the live ones refresh while
/// they are expanded, and stop the moment they are collapsed or the screen is left.
class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  final _search = TextEditingController();
  String _query = '';
  final Set<String> _expanded = {'device'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final info = Services.read(context).info;
    info.refreshInterval = Services.read(context).settings.infoRefreshMs;
    await info.loadAllProgressively();
    if (mounted) info.setSectionVisible('device', true);
  }

  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // FR-INFO-4 / NFR-PERF-2 — a live section refreshes only while it is actually on screen.
    final visible = TabVisibility.of(context);
    if (visible == _visible) return;
    _visible = visible;
    final info = Services.read(context).info;
    if (visible) {
      for (final id in _expanded) {
        info.setSectionVisible(id, true);
      }
    } else {
      info.stopLiveRefresh();
    }
  }

  @override
  void deactivate() {
    Services.read(context).info.stopLiveRefresh();
    super.deactivate();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.infoTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.unfold_more_rounded),
            tooltip: strings.expandAll,
            onPressed: () => setState(
              () => _expanded
                ..clear()
                ..addAll(services.info.sections.map((s) => s.id)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: strings.reportTitle,
            onPressed: () => pushScreen(context, const ReportScreen()),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: services.info,
        builder: (context, _) {
          final controller = services.info;
          if (controller.loadingIndex && controller.sections.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_query.isNotEmpty) {
            final results = controller.search(_query);
            return Column(
              children: [
                SearchBox(
                  hint: strings.searchFields,
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                ),
                Expanded(
                  child: results.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No fields match "$_query"',
                          message:
                              'Only sections that have been opened at least once are searchable — '
                              'pull to refresh, or expand a section first.',
                        )
                      : ListView.separated(
                          itemCount: results.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                child: Text(
                                  results[i].section.title.toUpperCase(),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                ),
                              ),
                              CopyableField(field: results[i].field),
                            ],
                          ),
                        ),
                ),
              ],
            );
          }

          return Column(
            children: [
              SearchBox(
                hint: strings.searchFields,
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    for (final s in controller.sections) {
                      await controller.loadSection(s.id, force: true);
                    }
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: Insets.scrollBottom),
                    itemCount: controller.sections.length,
                    itemBuilder: (context, i) {
                      final section = controller.sections[i];
                      return _SectionCard(
                        section: section,
                        loading: controller.isLoading(section.id),
                        expanded: _expanded.contains(section.id),
                        onExpanded: (open) {
                          setState(() {
                            if (open) {
                              _expanded.add(section.id);
                            } else {
                              _expanded.remove(section.id);
                            }
                          });
                          controller.setSectionVisible(section.id, open);
                          if (open) unawaited(controller.loadSection(section.id));
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.loading,
    required this.expanded,
    required this.onExpanded,
  });

  final InfoSection section;
  final bool loading;
  final bool expanded;
  final ValueChanged<bool> onExpanded;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final restricted = section.restrictedCount;

    return Card(
      child: ExpansionTile(
        key: PageStorageKey(section.id),
        initiallyExpanded: expanded,
        onExpansionChanged: onExpanded,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: Corners.rXs,
          ),
          child: Icon(_sectionIcon(section.id), size: 18, color: scheme.primary),
        ),
        title: Row(
          children: [
            Expanded(child: Text(section.title)),
            // FR-INFO-4 — the dot only breathes while this section is actually sampling.
            if (section.live)
              Padding(
                padding: const EdgeInsets.only(right: Insets.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusDot(colour: context.palette.success, live: expanded, size: 7),
                    const SizedBox(width: 5),
                    Text(
                      'live',
                      style: context.texts.labelSmall
                          ?.copyWith(color: context.palette.success),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Text(
          section.isLoaded
              ? '${section.fields.length} fields'
                  '${restricted > 0 ? ' · $restricted restricted' : ''}'
              : strings.loading,
        ),
        trailing: loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                    tooltip: strings.copySection,
                    onPressed: section.isLoaded
                        ? () async {
                            await Clipboard.setData(ClipboardData(text: section.asText()));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context)
                              ..clearSnackBars()
                              ..showSnackBar(
                                SnackBar(content: Text('${strings.copied}: ${section.title}')),
                              );
                          }
                        : null,
                  ),
                  Icon(
                    expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
        children: [
          if (section.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: scheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${strings.sectionFailed}: ${section.error}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          if (!section.isLoaded && section.error == null)
            const Padding(
              padding: EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 200),
                  SizedBox(height: Insets.xs),
                  Skeleton(width: 260),
                  SizedBox(height: Insets.xs),
                  Skeleton(width: 160),
                ],
              ),
            ),
          for (final field in section.fields) CopyableField(field: field),
          const SizedBox(height: Insets.xs),
        ],
      ),
    );
  }

  /// A glyph per section, so the dashboard scans by shape as well as by title.
  static IconData _sectionIcon(String id) => switch (id) {
        'device' => Icons.smartphone_outlined,
        'os' => Icons.security_outlined,
        'display' => Icons.display_settings_outlined,
        'cpu' => Icons.developer_board_rounded,
        'gpu' => Icons.view_in_ar_outlined,
        'memory' => Icons.memory_rounded,
        'storage' => Icons.sd_storage_outlined,
        'battery' => Icons.battery_charging_full_rounded,
        'thermal' => Icons.thermostat_rounded,
        'network' => Icons.lan_outlined,
        'telephony' => Icons.signal_cellular_alt_rounded,
        'sensors' => Icons.sensors_rounded,
        'cameras' => Icons.photo_camera_outlined,
        'system' => Icons.tune_rounded,
        _ => Icons.info_outline_rounded,
      };
}
