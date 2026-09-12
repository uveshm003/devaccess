import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/models/toggle.dart';
import '../../core/state/services.dart';
import 'toggles_screen.dart';

/// FR-QA-6 — the destination when a global search result is a toggle rather than a
/// launcher. Shows the same control the toggles tab would, so a search is one tap from
/// acting on the setting.
class SingleToggleScreen extends StatelessWidget {
  const SingleToggleScreen({required this.spec, super.key});

  final ToggleSpec spec;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(spec.label),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: strings.refresh,
            onPressed: () => services.toggles.refreshOne(spec.id),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([services.toggles, services.tier]),
        builder: (context, _) => ListView(
          children: [
            Card(child: ToggleRow(spec: spec)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Writes to ${spec.scope}.${spec.key} need tier ${spec.requiredTier.code}. '
                'DevAccess re-reads the key after every write and shows what the OS actually '
                'stored.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
