import 'package:devaccess/core/models/launcher.dart';
import 'package:devaccess/core/models/tier.dart';
import 'package:devaccess/core/models/toggle.dart';
import 'package:devaccess/data/launcher_catalog.dart';
import 'package:devaccess/data/toggle_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LauncherCatalog', () {
    test('FR-QA-1 — every Appendix A category is covered', () {
      for (final category in LauncherCategory.values) {
        expect(
          LauncherCatalog.inCategory(category),
          isNotEmpty,
          reason: 'category ${category.title} has no launchers',
        );
      }
    });

    test('ids are unique', () {
      final ids = LauncherCatalog.all.map((l) => l.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('NFR-COMPAT-1 — every launcher ends in a fallback that always resolves', () {
      for (final spec in LauncherCatalog.all) {
        expect(spec.chain, isNotEmpty, reason: '${spec.id} has an empty chain');
        expect(
          spec.chain.last.action,
          'android.settings.SETTINGS',
          reason: '${spec.id} does not fall back to the main Settings screen',
        );
      }
    });

    test('FR-QA-2 — the developer-options launcher leads with the public action', () {
      final dev = LauncherCatalog.byId('dev_options')!;
      expect(dev.chain.first.action, 'android.settings.APPLICATION_DEVELOPMENT_SETTINGS');
      expect(dev.chain.length, greaterThan(1));
    });

    test('FR-QA-6 — search matches labels and synonyms', () {
      final byLabel = LauncherCatalog.all.where((l) => l.matches('wi-fi'));
      expect(byLabel, isNotEmpty);
      final bySynonym = LauncherCatalog.all.where((l) => l.matches('ssid'));
      expect(bySynonym.map((l) => l.id), contains('wifi'));
      final byCategory = LauncherCatalog.all.where((l) => l.matches('storage'));
      expect(byCategory, isNotEmpty);
    });

    test('intent specs serialise only the fields they set', () {
      const spec = IntentSpec(action: 'a', data: 'b');
      expect(spec.toMap(), {'action': 'a', 'data': 'b'});
    });
  });

  group('ToggleCatalog', () {
    test('ids are unique', () {
      final ids = ToggleCatalog.all.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('FR-TG-1 — all three animation scales are present as T2 float writes', () {
      expect(ToggleCatalog.animationScales, hasLength(3));
      for (final spec in ToggleCatalog.animationScales) {
        expect(spec.scope, 'global');
        expect(spec.type, 'float');
        expect(spec.requiredTier, AccessTier.t2);
        expect(spec.presets.map((p) => p.value), contains('0.0'));
      }
    });

    test('FR-TG-2/3/4 — the named developer flags exist at the right tier', () {
      const expected = {
        'adb_enabled': AccessTier.t2,
        'stay_on_while_plugged_in': AccessTier.t2,
        'show_touches': AccessTier.t2,
        'pointer_location': AccessTier.t2,
      };
      expected.forEach((id, tier) {
        final spec = ToggleCatalog.byId(id);
        expect(spec, isNotNull, reason: '$id is missing');
        expect(spec!.requiredTier, tier);
      });
    });

    test('FR-TG-6 — Settings.System toggles are writable at T1', () {
      for (final id in const ['screen_brightness', 'screen_off_timeout']) {
        final spec = ToggleCatalog.byId(id)!;
        expect(spec.scope, 'system');
        expect(spec.requiredTier, AccessTier.t1);
      }
    });

    test('FR-TG-7 — read-only entries deep-link instead of faking a toggle', () {
      final readOnly = ToggleCatalog.all.where((t) => t.kind == ToggleKind.readOnly);
      expect(readOnly, isNotEmpty);
      for (final spec in readOnly) {
        expect(spec.writable, isFalse);
        expect(spec.launcherId, isNotNull, reason: '${spec.id} has no fallback launcher');
        expect(spec.note, isNotNull, reason: '${spec.id} does not explain itself');
      }
    });

    test('every launcherId points at a real launcher', () {
      for (final spec in ToggleCatalog.all) {
        if (spec.launcherId == null) continue;
        expect(
          LauncherCatalog.byId(spec.launcherId!),
          isNotNull,
          reason: '${spec.id} references a missing launcher "${spec.launcherId}"',
        );
      }
    });

    test('choice toggles carry presets, sliders carry a range', () {
      for (final spec in ToggleCatalog.all) {
        if (spec.kind == ToggleKind.choice) {
          expect(spec.presets, isNotEmpty, reason: '${spec.id} has no presets');
        }
        if (spec.kind == ToggleKind.slider) {
          expect(spec.max, greaterThan(spec.min), reason: '${spec.id} has an empty range');
        }
      }
    });

    test('grouping covers every toggle exactly once or leaves it searchable', () {
      final grouped = ToggleCatalog.grouped().values.expand((e) => e).map((e) => e.id).toSet();
      expect(grouped, hasLength(ToggleCatalog.all.length));
    });
  });
}
