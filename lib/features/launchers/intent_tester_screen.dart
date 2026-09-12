import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/models/tier.dart';
import '../../core/state/services.dart';
import '../../widgets/common.dart';
import '../../widgets/locked_badge.dart';
import '../tier/tier_screen.dart';

/// FR-QA-7 — fire an arbitrary action/URI to validate a deep link.
///
/// Guarded per the requirement: the off-Play flavour always has it; the Play flavour needs
/// tier T2 or above. When it is locked the control stays visible with a badge and an
/// explanation (FR-TIER-3) rather than disappearing.
class IntentTesterScreen extends StatefulWidget {
  const IntentTesterScreen({super.key});

  @override
  State<IntentTesterScreen> createState() => _IntentTesterScreenState();
}

class _IntentTesterScreenState extends State<IntentTesterScreen> {
  final _action = TextEditingController(text: 'android.settings.SETTINGS');
  final _data = TextEditingController();
  final _package = TextEditingController();
  final _component = TextEditingController();
  final _category = TextEditingController();
  final _mime = TextEditingController();

  String? _outcome;
  bool _resolves = false;
  bool _checked = false;

  @override
  void dispose() {
    for (final c in [_action, _data, _package, _component, _category, _mime]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _spec => {
        if (_action.text.trim().isNotEmpty) 'action': _action.text.trim(),
        if (_data.text.trim().isNotEmpty) 'data': _data.text.trim(),
        if (_package.text.trim().isNotEmpty) 'package': _package.text.trim(),
        if (_component.text.trim().isNotEmpty) 'component': _component.text.trim(),
        if (_category.text.trim().isNotEmpty) 'category': _category.text.trim(),
        if (_mime.text.trim().isNotEmpty) 'mime': _mime.text.trim(),
      };

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);
    final status = services.tier.status;
    final unlocked = status.fullAccessBuild || status.tier.level >= AccessTier.t2.level;

    return Scaffold(
      appBar: AppBar(title: Text(strings.intentTester)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(strings.intentTesterHelp, style: Theme.of(context).textTheme.bodyMedium),
          if (!unlocked) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                LockedBadge(
                  requiredTier: AccessTier.t2,
                  currentTier: status.tier,
                  reason: strings.intentTesterHelp,
                  onUnlock: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const UnlockT2Wizard()),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          _field(_action, 'Action', 'android.settings.WIFI_SETTINGS'),
          _field(_data, 'Data URI', 'package:com.example.app'),
          _field(_package, 'Target package', 'com.android.settings'),
          _field(_component, 'Component', 'com.android.settings/.Settings\$WifiSettingsActivity'),
          _field(_category, 'Category', 'android.intent.category.DEFAULT'),
          _field(_mime, 'MIME type', 'text/plain'),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final results = await services.bridge.resolveMany([_spec]);
                  setState(() {
                    _checked = true;
                    _resolves = results.isNotEmpty && results.first;
                  });
                },
                icon: const Icon(Icons.search),
                label: const Text('Resolve'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: unlocked ? _fire : null,
                icon: const Icon(Icons.send),
                label: Text(strings.fire),
              ),
            ],
          ),
          if (_checked) ...[
            const SizedBox(height: 16),
            Pill(
              _resolves ? 'An activity handles this intent' : 'Nothing on this device handles it',
              colour: _resolves
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
              icon: _resolves ? Icons.check : Icons.close,
            ),
          ],
          if (_outcome != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SelectableText(_outcome!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          decoration: InputDecoration(labelText: label, hintText: hint),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      );

  Future<void> _fire() async {
    final result = await Services.read(context).bridge.customIntent(_spec);
    if (!mounted) return;
    setState(() {
      _outcome = result['ok'] == true
          ? 'Fired successfully via ${result['used']}'
          : 'Failed: ${result['error'] ?? 'unknown error'}';
    });
  }
}
