import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/strings.dart';
import '../../core/models/tier.dart';
import '../../core/state/services.dart';
import '../../widgets/common.dart';

/// FR-TIER-1 / FR-TIER-2 — shows the current tier, what each higher tier adds, and hosts
/// the guided unlock flows.
class TierScreen extends StatelessWidget {
  const TierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.tierScreenTitle)),
      body: ListenableBuilder(
        listenable: services.tier,
        builder: (context, _) {
          final status = services.tier.status;
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _CurrentTierCard(status: status),
              SectionHeader(strings.whatEachTierAdds),
              for (final tier in AccessTier.values)
                _TierRow(tier: tier, status: status),
              SectionHeader('Unlock'),
              if (!status.canWriteSystem)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.tune),
                    title: Text(strings.unlockT1),
                    subtitle: const Text(
                      'Opens the "Modify system settings" special-access screen. This is the '
                      'only permission Android lets an app request for Settings.System writes '
                      '(C3) — it does not cover developer options.',
                    ),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    isThreeLine: true,
                    onTap: () => services.tier.requestWriteSettings(),
                  ),
                ),
              if (!status.canWriteSecure)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.usb),
                    title: Text(strings.unlockT2),
                    subtitle: const Text(
                      'One adb command grants WRITE_SECURE_SETTINGS permanently. Android '
                      'never offers this in a permission dialog (C1).',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    isThreeLine: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const UnlockT2Wizard()),
                    ),
                  ),
                ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.terminal),
                  title: Text(strings.probeRoot),
                  subtitle: Text(
                    status.rootProbed
                        ? (status.hasRoot
                            ? 'su returned uid 0 — DevAccess is on T3.'
                            : 'su did not return uid 0.')
                        : strings.rootProbeHint,
                  ),
                  trailing: services.tier.loading
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_arrow),
                  isThreeLine: true,
                  onTap: services.tier.loading ? null : () => services.tier.probeRoot(),
                ),
              ),
              _IntegrityCard(status: status),
            ],
          );
        },
      ),
    );
  }
}

class _CurrentTierCard extends StatelessWidget {
  const _CurrentTierCard({required this.status});

  final TierStatus status;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.currentTier, style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            Text(
              '${status.tier.code} — ${status.tier.title}',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Pill(
                  'WRITE_SETTINGS ${status.canWriteSystem ? "granted" : "not granted"}',
                  colour: status.canWriteSystem ? theme.colorScheme.primary : theme.colorScheme.outline,
                ),
                Pill(
                  'WRITE_SECURE_SETTINGS ${status.canWriteSecure ? "granted" : "not granted"}',
                  colour: status.canWriteSecure ? theme.colorScheme.primary : theme.colorScheme.outline,
                ),
                Pill(
                  status.hasRoot
                      ? 'root granted'
                      : (status.rootProbed ? 'no root' : 'root not probed'),
                  colour: status.hasRoot ? theme.colorScheme.error : theme.colorScheme.outline,
                ),
                Pill('API ${status.sdkInt}', colour: theme.colorScheme.tertiary),
                Pill('${status.flavor} build', colour: theme.colorScheme.tertiary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({required this.tier, required this.status});

  final AccessTier tier;
  final TierStatus status;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final available = status.tier.level >= tier.level;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: ExpansionTile(
        leading: Icon(
          available ? Icons.check_circle : Icons.lock_outline,
          color: available ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Text('${tier.code} — ${tier.title}'),
        subtitle: Text(available ? 'Available now' : 'Not unlocked'),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.howToGet, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(tier.howToGet),
          const SizedBox(height: 12),
          Text('Unlocks', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(tier.unlocks),
        ],
      ),
    );
  }
}

/// FR-INFO-5 — root / bootloader / integrity signals, surfaced next to the tier they affect.
class _IntegrityCard extends StatelessWidget {
  const _IntegrityCard({required this.status});

  final TierStatus status;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Integrity signals', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _kv(context, 'su binary', status.suBinary ?? 'not found'),
            _kv(
              context,
              'Magisk artifacts',
              status.magiskArtifacts.isEmpty ? 'none' : status.magiskArtifacts.join(', '),
            ),
            _kv(
              context,
              'Build signals',
              status.buildSignals.isEmpty ? 'none' : status.buildSignals.join(', '),
            ),
            _kv(context, 'DUMP permission', status.hasDump ? 'granted (adb)' : 'not granted'),
            const SizedBox(height: 8),
            Text(
              'Play Integrity is not evaluated: it needs a Google Cloud project and a '
              'server-side verdict check, and DevAccess ships no backend (NFR-PRIV-1). '
              'Verified-boot state and the signals above are the on-device substitute.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(k,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Expanded(child: SelectableText(v, style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      );
}

/// FR-TIER-2 — the guided T2 unlock: exact command, wireless-debugging help, verification.
class UnlockT2Wizard extends StatefulWidget {
  const UnlockT2Wizard({super.key});

  @override
  State<UnlockT2Wizard> createState() => _UnlockT2WizardState();
}

class _UnlockT2WizardState extends State<UnlockT2Wizard> {
  bool _verifying = false;
  bool? _verified;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);
    final status = services.tier.status;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.unlockT2Title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(strings.unlockT2Intro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 20),
          _Step(
            number: 1,
            title: 'Enable USB debugging on this device',
            child: const Text(
              'Settings → About phone → tap Build number seven times, then '
              'Settings → Developer options → USB debugging.',
            ),
          ),
          _Step(
            number: 2,
            title: 'Connect to a computer with adb',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('A USB cable is the simplest route.'),
                if (status.wirelessDebuggingSupported) ...[
                  const SizedBox(height: 10),
                  Text(strings.wirelessDebugging, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(strings.wirelessDebuggingHelp, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          _Step(
            number: 3,
            title: 'Run this command',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CommandBlock(command: status.adbCommand),
                const SizedBox(height: 10),
                Text(
                  'Optional extras, for features that need them:',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                _CommandBlock(command: status.adbDumpCommand, subtitle: 'SystemUI demo mode'),
                const SizedBox(height: 6),
                _CommandBlock(
                  command: status.adbLogsCommand,
                  subtitle: 'Logcat access (backlog feature)',
                ),
              ],
            ),
          ),
          _Step(
            number: 4,
            title: 'Verify',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _verifying
                          ? null
                          : () async {
                              setState(() => _verifying = true);
                              final ok = await services.tier.verifySecureGrant();
                              if (!mounted) return;
                              setState(() {
                                _verifying = false;
                                _verified = ok;
                              });
                            },
                      icon: _verifying
                          ? const SizedBox(
                              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.verified_outlined),
                      label: Text(strings.verifyGrant),
                    ),
                  ],
                ),
                if (_verified != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        _verified! ? Icons.check_circle : Icons.error_outline,
                        color: _verified! ? theme.colorScheme.primary : theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_verified! ? strings.grantVerified : strings.grantNotFound),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'The grant survives reboots and stays until DevAccess is uninstalled. It lets '
                'DevAccess write developer and global settings — it does not give the app any '
                'other elevated capability, and nothing is sent off the device.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.child});

  final int number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: scheme.primaryContainer,
            child: Text('$number', style: TextStyle(color: scheme.onPrimaryContainer)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandBlock extends StatelessWidget {
  const _CommandBlock({required this.command, this.subtitle});

  final String command;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      subtitle!,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                SelectableText(
                  command,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: strings.copyCommand,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: command));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(SnackBar(content: Text(strings.commandCopied)));
            },
          ),
        ],
      ),
    );
  }
}
