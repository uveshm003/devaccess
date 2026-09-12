import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/l10n/strings.dart';
import '../core/models/info_field.dart';

/// FR-INFO-2 / FR-INFO-3 — one dashboard row.
///
/// Long-press (or the trailing button, for TalkBack users) copies the value. Fields the OS
/// restricts render the reason rather than a blank or a fabricated value.
class CopyableField extends StatelessWidget {
  const CopyableField({required this.field, this.highlight, super.key});

  final InfoField field;

  /// Search term to emphasise, when the row is shown in search results.
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ok = field.isOk;

    return Semantics(
      label: '${field.label}: ${field.displayValue}',
      child: InkWell(
        onLongPress: ok ? () => _copy(context, strings) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            field.label,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (field.sensitive) ...[
                          const SizedBox(width: 6),
                          // NFR-PRIV-2 — identifiers are labelled where they are shown.
                          Tooltip(
                            message: 'Privacy-sensitive: masked when redaction is on',
                            child: Icon(
                              Icons.shield_outlined,
                              size: 13,
                              color: scheme.tertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      field.displayValue,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: ok ? scheme.onSurface : scheme.onSurfaceVariant,
                        fontStyle: ok ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
                    if (!ok && field.reason != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        field.reason!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (ok)
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: strings.copyField,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _copy(context, strings),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, AppStrings strings) async {
    await Clipboard.setData(ClipboardData(text: field.displayValue));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('${strings.copied}: ${field.label}')));
  }
}
