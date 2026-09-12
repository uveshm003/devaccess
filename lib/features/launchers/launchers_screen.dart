import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/models/launcher.dart';
import '../../core/models/toggle.dart';
import '../../core/state/services.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/launcher_catalog.dart';
import '../../data/toggle_catalog.dart';
import '../../widgets/common.dart';
import '../shell/app_shell.dart';
import '../toggles/single_toggle_screen.dart';
import 'intent_tester_screen.dart';

/// FR-QA-1..7 — the searchable, categorised launcher hub.
class LaunchersScreen extends StatefulWidget {
  const LaunchersScreen({super.key});

  @override
  State<LaunchersScreen> createState() => _LaunchersScreenState();
}

class _LaunchersScreenState extends State<LaunchersScreen> {
  final _search = TextEditingController();
  String _query = '';

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
        title: Text(strings.launchersTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_outlined),
            tooltip: strings.intentTester,
            onPressed: () => pushScreen(context, const IntentTesterScreen()),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([services.settings, services.tier]),
        builder: (context, _) {
          final favourites = services.settings.favouriteLaunchers
              .map(LauncherCatalog.byId)
              .whereType<LauncherSpec>()
              .toList(growable: false);

          // FR-QA-6 — one search box spans launchers and toggles.
          final matchingToggles = _query.isEmpty
              ? const <ToggleSpec>[]
              : ToggleCatalog.all.where((t) => t.matches(_query)).toList(growable: false);

          final sections = <Widget>[
            for (final category in LauncherCategory.values)
              ..._categorySection(context, category, strings),
          ];

          return Column(
            children: [
              SearchBox(
                hint: strings.searchLaunchers,
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
              ),
              if (sections.isEmpty && matchingToggles.isEmpty)
                Expanded(
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Nothing matches "$_query"',
                    message:
                        'Search covers launcher labels, their synonyms and every toggle key.',
                    action: OutlinedButton.icon(
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Clear search'),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                  padding: const EdgeInsets.only(bottom: Insets.scrollBottom),
                  children: [
                    if (_query.isEmpty && favourites.isNotEmpty) ...[
                      SectionHeader(strings.favourites, icon: Icons.push_pin_outlined),
                      _LauncherGrid(specs: favourites, query: _query),
                    ],
                    if (matchingToggles.isNotEmpty) ...[
                      SectionHeader(
                        strings.togglesTitle,
                        icon: Icons.toggle_on_outlined,
                        subtitle: '${matchingToggles.length} matching toggles',
                      ),
                      for (final t in matchingToggles.take(6))
                        ListTile(
                          leading: Icon(t.icon),
                          title: Text(t.label),
                          subtitle: Text('${t.scope}.${t.key} · writes at ${t.requiredTier.code}'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => pushScreen(context, SingleToggleScreen(spec: t)),
                        ),
                    ],
                    ...sections,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _categorySection(
    BuildContext context,
    LauncherCategory category,
    AppStrings strings,
  ) {
    final specs = LauncherCatalog.inCategory(category)
        .where((s) => s.matches(_query))
        .toList(growable: false);
    if (specs.isEmpty) return const [];
    return [
      SectionHeader(category.title, icon: category.icon),
      _LauncherGrid(specs: specs, query: _query),
    ];
  }
}

class _LauncherGrid extends StatelessWidget {
  const _LauncherGrid({required this.specs, required this.query});

  final List<LauncherSpec> specs;
  final String query;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: Insets.xs,
        crossAxisSpacing: Insets.xs,
        childAspectRatio: 2.6,
        children: [for (final spec in specs) _LauncherCard(spec: spec)],
      ),
    );
  }
}

class _LauncherCard extends StatelessWidget {
  const _LauncherCard({required this.spec});

  final LauncherSpec spec;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pinned = services.settings.isFavouriteLauncher(spec.id);
    final tooNew = spec.minSdk != null && services.tier.status.sdkInt < spec.minSdk!;

    return Semantics(
      button: true,
      label: '${spec.label}. ${spec.description ?? ''}',
      child: Material(
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: Corners.rMd,
          side: BorderSide(
            color: pinned
                ? scheme.primary.withValues(alpha: 0.4)
                : context.palette.hairline,
          ),
        ),
        child: InkWell(
          borderRadius: Corners.rMd,
          onTap: () => _launch(context, strings),
          onLongPress: () => services.settings.toggleFavouriteLauncher(spec.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, Insets.xs, 2, Insets.xs),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: Corners.rXs,
                  ),
                  child: Icon(spec.icon, size: 16, color: scheme.primary),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        spec.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              height: 1.2,
                              color: scheme.onSurface,
                            ),
                      ),
                      if (tooNew)
                        Text(
                          'Needs API ${spec.minSdk}',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                // Compact on purpose: the label is the content, and the row is only
                // ~180dp wide on a phone.
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  iconSize: 16,
                  icon: Icon(
                    pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: pinned ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  tooltip: pinned ? strings.unpin : strings.pin,
                  onPressed: () => services.settings.toggleFavouriteLauncher(spec.id),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// NFR-COMPAT-1 — reports which link in the chain actually fired.
  Future<void> _launch(BuildContext context, AppStrings strings) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await Services.read(context).bridge.launchChain(spec.chainMaps);
    if (result['ok'] == true) {
      if (result['fallbackUsed'] == true) {
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text('${strings.fellBackTo} ${result['used']}')),
          );
      }
      return;
    }
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(result['error'] as String? ?? strings.launchFailed),
          duration: const Duration(seconds: 5),
        ),
      );
  }
}
