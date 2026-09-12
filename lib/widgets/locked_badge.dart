import 'package:flutter/material.dart';

import '../core/l10n/strings.dart';
import '../core/models/tier.dart';

/// FR-TIER-3 — every control the current tier cannot perform renders this badge, with a
/// one-tap explanation. Controls are never hidden and never fail silently.
class LockedBadge extends StatelessWidget {
  const LockedBadge({
    required this.requiredTier,
    required this.currentTier,
    this.reason,
    this.onUnlock,
    this.compact = false,
    super.key,
  });

  final AccessTier requiredTier;
  final AccessTier currentTier;

  /// A more specific explanation than "you need tier X".
  final String? reason;
  final VoidCallback? onUnlock;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final label = '${strings.lockedBadge} · ${requiredTier.code}';

    return Semantics(
      button: true,
      label: '$label. ${strings.whyLocked}',
      child: Tooltip(
        message: reason ?? _defaultReason(strings),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _explain(context, strings),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: compact ? 13 : 15, color: scheme.onSurfaceVariant),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _defaultReason(AppStrings strings) =>
      'This needs tier ${requiredTier.code} (${requiredTier.title}). '
      'DevAccess currently has ${currentTier.code}.';

  void _explain(BuildContext context, AppStrings strings) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${requiredTier.code} — ${requiredTier.title}',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(reason ?? _defaultReason(strings)),
              const SizedBox(height: 14),
              Text(strings.howToGet, style: Theme.of(sheetContext).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(requiredTier.howToGet),
              const SizedBox(height: 14),
              Text(requiredTier.unlocks,
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                        color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                      )),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (onUnlock != null)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        onUnlock!();
                      },
                      icon: const Icon(Icons.lock_open_outlined),
                      label: Text('${strings.unlockT2.split(' ').first} ${requiredTier.code}'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(strings.close),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
