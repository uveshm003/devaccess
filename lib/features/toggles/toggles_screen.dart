import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/models/tier.dart';
import '../../core/models/toggle.dart';
import '../../core/state/services.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/launcher_catalog.dart';
import '../../data/toggle_catalog.dart';
import '../../widgets/common.dart';
import '../../widgets/locked_badge.dart';
import '../shell/app_shell.dart';
import '../tier/tier_screen.dart';
import 'audit_log_screen.dart';

/// FR-TG-1..8 — the toggle surface. Every control is visible at every tier; the ones the
/// current tier cannot write carry a locked badge (FR-TIER-3) and a deep link instead.
class TogglesScreen extends StatefulWidget {
  const TogglesScreen({super.key});

  @override
  State<TogglesScreen> createState() => _TogglesScreenState();
}

class _TogglesScreenState extends State<TogglesScreen> {
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
        title: Text(strings.togglesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: strings.auditLog,
            onPressed: () => pushScreen(context, const AuditLogScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: strings.refresh,
            onPressed: () => services.toggles.refreshAll(),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([services.toggles, services.tier, services.settings]),
        builder: (context, _) {
          final groups = ToggleCatalog.grouped();
          final rows = <Widget>[
            for (final entry in groups.entries) ..._group(context, entry.key, entry.value),
          ];
          return Column(
            children: [
              SearchBox(
                hint: strings.searchFields,
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
              ),
              if (rows.isEmpty)
                Expanded(
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No toggle matches "$_query"',
                    message: 'Search covers the label, the Settings key and the synonyms.',
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
                      if (_query.isEmpty) ...[
                        const _AnimationShortcuts(),
                        const _DemoModeCard(),
                      ],
                      ...rows,
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _group(BuildContext context, String title, List<ToggleSpec> specs) {
    final visible = specs.where((s) => s.matches(_query)).toList(growable: false);
    if (visible.isEmpty) return const [];
    return [
      SectionHeader(title),
      Card(
        child: Column(
          children: [
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              ToggleRow(spec: visible[i]),
            ],
          ],
        ),
      ),
    ];
  }
}

/// FR-TG-1 — the presets and the one-tap "kill all animations".
class _AnimationShortcuts extends StatelessWidget {
  const _AnimationShortcuts();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);
    final spec = ToggleCatalog.animationScales.first;
    final canWrite = services.toggles.canWrite(spec);
    final off = services.toggles.animationsOff;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Animation scales',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                if (!canWrite)
                  LockedBadge(
                    requiredTier: AccessTier.t2,
                    currentTier: services.tier.tier,
                    onUnlock: () => pushScreen(context, const UnlockT2Wizard()),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Window, transition and animator scales together.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: canWrite
                      ? () => _applyAll(context, off ? '1.0' : '0.0')
                      : null,
                  icon: Icon(off ? Icons.play_arrow : Icons.flash_off, size: 18),
                  label: Text(off ? strings.restoreAnimations : strings.killAnimations),
                ),
                for (final preset in const ['0.0', '0.5', '1.0', '2.0'])
                  OutlinedButton(
                    onPressed: canWrite ? () => _applyAll(context, preset) : null,
                    child: Text(preset == '0.0' ? 'Off' : '$preset×'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyAll(BuildContext context, String value) async {
    final services = Services.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final strings = AppStrings.of(context);
    final outcomes = await services.toggles.setAllAnimationScales(value);
    final failed = outcomes.where((o) => !o.ok).toList(growable: false);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            failed.isEmpty
                ? '${strings.writeApplied}: animation scales → $value'
                : '${strings.writeRejected}: ${failed.first.error}',
          ),
          action: failed.isEmpty
              ? SnackBarAction(
                  label: strings.undo,
                  onPressed: () => services.toggles.setAllAnimationScales(
                    outcomes.first.previous ?? '1.0',
                  ),
                )
              : null,
        ),
      );
  }
}

/// FR-TG-5 — SystemUI demo mode with a clean status bar for screenshots.
class _DemoModeCard extends StatelessWidget {
  const _DemoModeCard();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);
    final status = services.tier.status;
    final canWrite = status.canWriteSecure || status.hasRoot;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_camera_outlined),
                const SizedBox(width: 10),
                Expanded(child: Text(strings.demoMode,
                    style: Theme.of(context).textTheme.titleSmall)),
                if (!canWrite)
                  LockedBadge(
                    requiredTier: AccessTier.t2,
                    currentTier: status.tier,
                    onUnlock: () => pushScreen(context, const UnlockT2Wizard()),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Freezes the status bar into a clean preset — full signal, 100% battery, no '
              'notification icons. The broadcast also needs the DUMP permission, which the '
              'unlock wizard lists as an optional adb grant.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: canWrite ? () => _set(context, true) : null,
                  child: const Text('Enter demo mode'),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: canWrite ? () => _set(context, false) : null,
                  child: const Text('Exit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _set(BuildContext context, bool enabled) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await Services.read(context).toggles.setDemoMode(enabled);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error ?? (enabled ? 'Demo mode enabled' : 'Demo mode disabled'),
          ),
        ),
      );
  }
}

/// One toggle row: current value at T0, an active control at the required tier.
class ToggleRow extends StatelessWidget {
  const ToggleRow({required this.spec, super.key});

  final ToggleSpec spec;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);
    final value = services.toggles.value(spec.id);
    final canWrite = services.toggles.canWrite(spec);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(spec.icon, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spec.label,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${spec.scope}.${spec.key}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _control(context, services, value, canWrite, strings),
            ],
          ),
          if (spec.description != null)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 6),
              child: Text(spec.description!,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          if (spec.kind == ToggleKind.choice && canWrite)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in spec.presets)
                    ChoiceChip(
                      label: Text(p.label),
                      selected: value?.raw != null && _sameValue(value!.raw!, p.value, spec.type),
                      onSelected: (_) => _write(context, spec, p.value),
                    ),
                ],
              ),
            ),
          if (spec.kind == ToggleKind.slider && canWrite)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 4),
              child: _SliderControl(spec: spec, value: value),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Now: ${value?.display ?? strings.loading}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: value?.isSet == true ? scheme.primary : scheme.onSurfaceVariant,
                        ),
                  ),
                ),
                if (spec.launcherId != null)
                  TextButton.icon(
                    onPressed: () => _openLauncher(context),
                    icon: const Icon(Icons.open_in_new, size: 15),
                    label: Text(
                      spec.kind == ToggleKind.readOnly
                          ? strings.toggleInSettings
                          : 'Settings',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          if (spec.note != null)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 4),
              child: Text(
                spec.note!,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  static bool _sameValue(String a, String b, String type) {
    if (type == 'float') {
      final x = double.tryParse(a), y = double.tryParse(b);
      return x != null && y != null && (x - y).abs() < 0.0001;
    }
    if (type == 'int' || type == 'long') {
      return int.tryParse(a.trim()) == int.tryParse(b.trim());
    }
    return a == b;
  }

  Widget _control(
    BuildContext context,
    Services services,
    ToggleValue? value,
    bool canWrite,
    AppStrings strings,
  ) {
    if (!canWrite) {
      return LockedBadge(
        requiredTier: spec.requiredTier,
        currentTier: services.tier.tier,
        compact: true,
        reason: spec.kind == ToggleKind.readOnly
            ? (spec.note ??
                'Android exposes this only through its own Settings UI — there is no writable '
                    'key and no adb path, so DevAccess deep-links to it instead of faking a toggle.')
            : null,
        onUnlock: spec.requiredTier == AccessTier.t2
            ? () => pushScreen(context, const UnlockT2Wizard())
            : null,
      );
    }
    if (spec.kind == ToggleKind.boolean) {
      return Switch(
        value: value?.on ?? false,
        onChanged: (v) => _write(context, spec, v ? spec.onValue : spec.offValue),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _openLauncher(BuildContext context) async {
    final launcher = LauncherCatalog.byId(spec.launcherId!);
    if (launcher == null) return;
    await Services.read(context).bridge.launchChain(launcher.chainMaps);
  }

  Future<void> _write(BuildContext context, ToggleSpec spec, String value) =>
      applyToggleWrite(context, spec, value);
}

class _SliderControl extends StatefulWidget {
  const _SliderControl({required this.spec, required this.value});

  final ToggleSpec spec;
  final ToggleValue? value;

  @override
  State<_SliderControl> createState() => _SliderControlState();
}

class _SliderControlState extends State<_SliderControl> {
  double? _pending;

  @override
  Widget build(BuildContext context) {
    final current =
        (_pending ?? widget.value?.asInt?.toDouble() ?? widget.spec.min.toDouble())
            .clamp(widget.spec.min.toDouble(), widget.spec.max.toDouble());
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: current,
            min: widget.spec.min.toDouble(),
            max: widget.spec.max.toDouble(),
            divisions: (widget.spec.max - widget.spec.min).clamp(1, 255),
            label: current.round().toString(),
            onChanged: (v) => setState(() => _pending = v),
            onChangeEnd: (v) async {
              await applyToggleWrite(context, widget.spec, v.round().toString());
              if (mounted) setState(() => _pending = null);
            },
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            current.round().toString(),
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}

/// NFR-SEC-1 — confirmation, then FR-TG-8 verification plus undo.
Future<void> applyToggleWrite(BuildContext context, ToggleSpec spec, String value) async {
  final services = Services.read(context);
  final strings = AppStrings.of(context);
  final messenger = ScaffoldMessenger.of(context);

  if (services.settings.confirmElevatedWrites && spec.requiredTier.level >= AccessTier.t2.level) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.confirmWriteTitle),
        content: Text(strings.confirmWriteBody(spec.label, value)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.ok),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
  }

  final outcome = await services.toggles.write(spec, value);
  final record = services.toggles.lastWrite;

  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(
          outcome.ok
              ? '${strings.writeApplied}: ${spec.label} → ${outcome.actual ?? value}'
              : '${strings.writeRejected}: ${outcome.error ?? 'unknown error'}',
        ),
        duration: Duration(seconds: outcome.ok ? 4 : 7),
        action: outcome.ok && record != null && record.undoable
            ? SnackBarAction(
                label: strings.undo,
                onPressed: () => services.toggles.undo(record),
              )
            : null,
      ),
    );
}
