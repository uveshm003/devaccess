import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/state/services.dart';
import '../../core/util/formatters.dart';
import '../../widgets/common.dart';

/// NFR-SEC-1 — the local, reviewable record of elevated writes, with undo.
class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.auditLog),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear log',
            onPressed: () => services.settings.clearAuditLog(),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: services.settings,
        builder: (context, _) {
          final log = services.settings.auditLog;
          if (log.isEmpty) {
            return EmptyState(
              icon: Icons.history_toggle_off,
              title: strings.noWritesYet,
              message: 'Every write to a protected system setting is recorded here so you '
                  'can review and undo it. Nothing is sent anywhere.',
            );
          }
          return ListView.separated(
            itemCount: log.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = log[i];
              return ListTile(
                leading: Icon(
                  r.ok ? Icons.check_circle_outline : Icons.error_outline,
                  color: r.ok
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
                title: Text('${r.label} → ${r.applied}'),
                subtitle: Text(
                  '${Fmt.timestamp(r.at)} · ${r.scope}.${r.key}'
                  '${r.previous == null ? '' : ' · was ${r.previous}'}'
                  '${r.ok ? ' · via ${r.method}' : ''}'
                  '${r.error == null ? '' : '\n${r.error}'}',
                ),
                isThreeLine: r.error != null,
                trailing: r.undoable
                    ? TextButton(
                        onPressed: () => services.toggles.undo(r),
                        child: Text(strings.undo),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
