import 'package:flutter/material.dart';

import '../core/models/tier.dart';
import '../core/models/toggle.dart';

/// FR-TG-1..7 — the developer toggles DevAccess exposes.
///
/// Each entry names the exact Settings key so the value is read honestly at T0 and written
/// only at the tier Android actually requires. Where no writable key exists the entry is
/// [ToggleKind.readOnly] and carries a `launcherId` so the UI can deep-link instead of
/// faking a switch (section 10).
abstract final class ToggleCatalog {
  static const animationKeys = [
    'window_animation_scale',
    'transition_animation_scale',
    'animator_duration_scale',
  ];

  static const List<TogglePreset> _scalePresets = [
    TogglePreset('Off', '0.0'),
    TogglePreset('0.5×', '0.5'),
    TogglePreset('1×', '1.0'),
    TogglePreset('1.5×', '1.5'),
    TogglePreset('2×', '2.0'),
    TogglePreset('5×', '5.0'),
  ];

  static const List<ToggleSpec> all = [
    // ---- FR-TG-1 animation scales ---------------------------------------
    ToggleSpec(
      id: 'window_animation_scale',
      label: 'Window animation scale',
      description: 'Duration multiplier for window open/close animations.',
      scope: 'global',
      key: 'window_animation_scale',
      type: 'float',
      kind: ToggleKind.choice,
      requiredTier: AccessTier.t2,
      icon: Icons.animation,
      presets: _scalePresets,
      synonyms: ['animation', 'window', 'speed', 'scale'],
      launcherId: 'dev_options',
    ),
    ToggleSpec(
      id: 'transition_animation_scale',
      label: 'Transition animation scale',
      description: 'Duration multiplier for activity transitions.',
      scope: 'global',
      key: 'transition_animation_scale',
      type: 'float',
      kind: ToggleKind.choice,
      requiredTier: AccessTier.t2,
      icon: Icons.swap_horiz,
      presets: _scalePresets,
      synonyms: ['animation', 'transition', 'speed', 'scale'],
      launcherId: 'dev_options',
    ),
    ToggleSpec(
      id: 'animator_duration_scale',
      label: 'Animator duration scale',
      description: 'Duration multiplier for ObjectAnimator-driven animations.',
      scope: 'global',
      key: 'animator_duration_scale',
      type: 'float',
      kind: ToggleKind.choice,
      requiredTier: AccessTier.t2,
      icon: Icons.timeline,
      presets: _scalePresets,
      synonyms: ['animation', 'animator', 'duration', 'scale'],
      launcherId: 'dev_options',
    ),

    // ---- FR-TG-2 USB debugging -------------------------------------------
    ToggleSpec(
      id: 'adb_enabled',
      label: 'USB debugging',
      description: 'The ADB_ENABLED global flag.',
      scope: 'global',
      key: 'adb_enabled',
      type: 'int',
      kind: ToggleKind.boolean,
      requiredTier: AccessTier.t2,
      icon: Icons.usb,
      synonyms: ['adb', 'usb debugging', 'debug bridge'],
      launcherId: 'dev_options',
      note: 'Some OEM builds refuse this write even at T2; the value is re-read after every '
          'attempt so the switch only moves if the OS really accepted it.',
    ),

    // ---- FR-TG-3 stay awake ----------------------------------------------
    ToggleSpec(
      id: 'stay_on_while_plugged_in',
      label: 'Stay awake while charging',
      description: 'STAY_ON_WHILE_PLUGGED_IN — a bitmask of the plug types that keep the '
          'screen on (AC 1 · USB 2 · wireless 4).',
      scope: 'global',
      key: 'stay_on_while_plugged_in',
      type: 'int',
      kind: ToggleKind.boolean,
      requiredTier: AccessTier.t2,
      icon: Icons.bolt,
      onValue: '7',
      offValue: '0',
      synonyms: ['stay awake', 'charging', 'screen on', 'plugged'],
      launcherId: 'dev_options',
    ),

    // ---- FR-TG-4 show touches / pointer location -------------------------
    ToggleSpec(
      id: 'show_touches',
      label: 'Show taps',
      description: 'Draws a visual dot at every touch point.',
      scope: 'system',
      key: 'show_touches',
      type: 'int',
      kind: ToggleKind.boolean,
      requiredTier: AccessTier.t2,
      icon: Icons.touch_app_outlined,
      synonyms: ['show touches', 'taps', 'recording', 'demo'],
      launcherId: 'dev_options',
    ),
    ToggleSpec(
      id: 'pointer_location',
      label: 'Pointer location',
      description: 'Overlays live touch coordinates and velocity.',
      scope: 'system',
      key: 'pointer_location',
      type: 'int',
      kind: ToggleKind.boolean,
      requiredTier: AccessTier.t2,
      icon: Icons.my_location_outlined,
      synonyms: ['pointer', 'coordinates', 'touch overlay'],
      launcherId: 'dev_options',
    ),

    // ---- FR-TG-6 Settings.System, writable at T1 --------------------------
    ToggleSpec(
      id: 'screen_brightness',
      label: 'Screen brightness',
      description: 'Raw backlight value, 0–255.',
      scope: 'system',
      key: 'screen_brightness',
      type: 'int',
      kind: ToggleKind.slider,
      requiredTier: AccessTier.t1,
      icon: Icons.brightness_medium,
      min: 0,
      max: 255,
      synonyms: ['brightness', 'backlight', 'screen'],
      launcherId: 'brightness',
      note: 'Turn adaptive brightness off first, or the system will immediately overwrite it.',
    ),
    ToggleSpec(
      id: 'screen_brightness_mode',
      label: 'Adaptive brightness',
      scope: 'system',
      key: 'screen_brightness_mode',
      type: 'int',
      kind: ToggleKind.boolean,
      requiredTier: AccessTier.t1,
      icon: Icons.brightness_auto,
      synonyms: ['adaptive', 'auto brightness'],
      launcherId: 'brightness',
    ),
    ToggleSpec(
      id: 'screen_off_timeout',
      label: 'Screen timeout',
      description: 'Milliseconds of inactivity before the screen turns off.',
      scope: 'system',
      key: 'screen_off_timeout',
      type: 'int',
      kind: ToggleKind.choice,
      requiredTier: AccessTier.t1,
      icon: Icons.timer_outlined,
      presets: [
        TogglePreset('15 s', '15000'),
        TogglePreset('30 s', '30000'),
        TogglePreset('1 min', '60000'),
        TogglePreset('2 min', '120000'),
        TogglePreset('5 min', '300000'),
        TogglePreset('10 min', '600000'),
        TogglePreset('30 min', '1800000'),
      ],
      synonyms: ['timeout', 'sleep', 'screen off'],
      launcherId: 'display',
    ),
    ToggleSpec(
      id: 'accelerometer_rotation',
      label: 'Auto-rotate screen',
      scope: 'system',
      key: 'accelerometer_rotation',
      type: 'int',
      kind: ToggleKind.boolean,
      requiredTier: AccessTier.t1,
      icon: Icons.screen_rotation,
      synonyms: ['rotate', 'orientation', 'accelerometer'],
      launcherId: 'auto_rotate',
    ),

    // ---- FR-TG-7 developer flags -----------------------------------------
    ToggleSpec(
      id: 'development_settings_enabled',
      label: 'Developer options enabled',
      description: 'The master switch for the developer options screen.',
      scope: 'global',
      key: 'development_settings_enabled',
      type: 'int',
      kind: ToggleKind.boolean,
      requiredTier: AccessTier.t2,
      icon: Icons.developer_mode,
      synonyms: ['developer options', 'enable', 'unlock'],
      launcherId: 'about_phone',
      note: 'Without T2, enable it by tapping Build number seven times in About phone.',
    ),
    ToggleSpec(
      id: 'always_finish_activities',
      label: "Don't keep activities",
      description: 'Destroys every activity as soon as the user leaves it.',
      scope: 'global',
      key: 'always_finish_activities',
      type: 'int',
      kind: ToggleKind.boolean,
      requiredTier: AccessTier.t2,
      icon: Icons.layers_clear_outlined,
      synonyms: ['dont keep activities', 'finish', 'lifecycle', 'process death'],
      launcherId: 'dev_options',
    ),
    ToggleSpec(
      id: 'debug_force_rtl',
      label: 'Force RTL layout direction',
      description: 'Forces right-to-left layout regardless of locale.',
      scope: 'global',
      key: 'debug.force_rtl',
      type: 'int',
      kind: ToggleKind.boolean,
      requiredTier: AccessTier.t2,
      icon: Icons.format_textdirection_r_to_l,
      synonyms: ['rtl', 'right to left', 'layout direction', 'arabic', 'hebrew'],
      launcherId: 'dev_options',
    ),
    ToggleSpec(
      id: 'app_process_limit',
      label: 'Background process limit',
      scope: 'global',
      key: 'app_process_limit',
      type: 'int',
      kind: ToggleKind.choice,
      requiredTier: AccessTier.t2,
      icon: Icons.dynamic_feed_outlined,
      presets: [
        TogglePreset('Standard', '-1'),
        TogglePreset('No background processes', '0'),
        TogglePreset('At most 1', '1'),
        TogglePreset('At most 2', '2'),
        TogglePreset('At most 3', '3'),
        TogglePreset('At most 4', '4'),
      ],
      synonyms: ['background process', 'limit', 'processes'],
      launcherId: 'dev_options',
    ),
    ToggleSpec(
      id: 'debug_layout',
      label: 'Show layout bounds',
      description: 'A SystemProperties flag, not a Settings key — writing it needs setprop.',
      scope: 'prop',
      key: 'debug.layout',
      type: 'string',
      kind: ToggleKind.boolean,
      requiredTier: AccessTier.t3,
      icon: Icons.grid_on_outlined,
      onValue: 'true',
      offValue: 'false',
      synonyms: ['layout bounds', 'clip bounds', 'margins', 'gpu'],
      launcherId: 'dev_options',
      note: 'SystemProperties are only writable through su, and SystemUI must be restarted '
          'for the change to take effect.',
    ),
    ToggleSpec(
      id: 'debug_hwui_overdraw',
      label: 'Debug GPU overdraw',
      description: 'A SystemProperties flag (debug.hwui.overdraw).',
      scope: 'prop',
      key: 'debug.hwui.overdraw',
      type: 'string',
      kind: ToggleKind.choice,
      requiredTier: AccessTier.t3,
      icon: Icons.gradient_outlined,
      presets: [
        TogglePreset('Off', 'false'),
        TogglePreset('Show overdraw areas', 'show'),
        TogglePreset('Deuteranomaly', 'show_deuteranomaly'),
      ],
      synonyms: ['overdraw', 'gpu', 'rendering', 'hwui'],
      launcherId: 'dev_options',
    ),
    ToggleSpec(
      id: 'debug_hwui_profile',
      label: 'Profile GPU rendering',
      scope: 'prop',
      key: 'debug.hwui.profile',
      type: 'string',
      kind: ToggleKind.choice,
      requiredTier: AccessTier.t3,
      icon: Icons.bar_chart,
      presets: [
        TogglePreset('Off', 'false'),
        TogglePreset('On screen as bars', 'visual_bars'),
        TogglePreset('In adb shell dumpsys gfxinfo', 'true'),
      ],
      synonyms: ['gpu profile', 'rendering', 'jank', 'frame'],
      launcherId: 'dev_options',
    ),

    // ---- FR-TG-7 read-only, deep-link only --------------------------------
    ToggleSpec(
      id: 'mock_location_app',
      label: 'Mock location app',
      description:
          'Selecting a mock-location app is an AppOps grant that only the Settings UI can '
          'make; ALLOW_MOCK_LOCATION was removed in Android 6 (API 23).',
      scope: 'secure',
      key: 'mock_location',
      type: 'int',
      kind: ToggleKind.readOnly,
      requiredTier: AccessTier.t3,
      icon: Icons.wrong_location_outlined,
      synonyms: ['mock location', 'fake gps', 'spoof'],
      launcherId: 'dev_options',
      note: 'Toggle in Settings → Developer options → Select mock location app.',
    ),
    ToggleSpec(
      id: 'usb_config',
      label: 'Default USB configuration',
      description: 'The USB function selected when a cable is plugged in.',
      scope: 'global',
      key: 'usb_default_config',
      type: 'string',
      kind: ToggleKind.readOnly,
      requiredTier: AccessTier.t3,
      icon: Icons.cable,
      synonyms: ['usb', 'mtp', 'ptp', 'file transfer'],
      launcherId: 'dev_options',
      note: 'Toggle in Settings → Developer options → Default USB configuration.',
    ),
    ToggleSpec(
      id: 'oem_unlock',
      label: 'OEM unlocking',
      description: 'Whether the bootloader may be unlocked.',
      scope: 'global',
      key: 'oem_unlock_allowed',
      type: 'int',
      kind: ToggleKind.readOnly,
      requiredTier: AccessTier.t3,
      icon: Icons.lock_open_outlined,
      synonyms: ['oem unlock', 'bootloader', 'unlock'],
      launcherId: 'dev_options',
      note: 'Deliberately not writable by DevAccess — this is a device-security switch that '
          'belongs in the Settings UI.',
    ),
  ];

  static ToggleSpec? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  static List<ToggleSpec> get animationScales =>
      all.where((t) => animationKeys.contains(t.key)).toList(growable: false);

  /// Grouping used by the toggles screen.
  static Map<String, List<ToggleSpec>> grouped() => {
        'Animations': animationScales,
        'Debugging': all
            .where((t) => const {
                  'adb_enabled',
                  'development_settings_enabled',
                  'stay_on_while_plugged_in',
                  'always_finish_activities',
                  'app_process_limit',
                }.contains(t.id))
            .toList(growable: false),
        'Input & layout': all
            .where((t) => const {
                  'show_touches',
                  'pointer_location',
                  'debug_force_rtl',
                  'debug_layout',
                }.contains(t.id))
            .toList(growable: false),
        'Display': all
            .where((t) => const {
                  'screen_brightness',
                  'screen_brightness_mode',
                  'screen_off_timeout',
                  'accelerometer_rotation',
                }.contains(t.id))
            .toList(growable: false),
        'Rendering': all
            .where((t) => const {'debug_hwui_overdraw', 'debug_hwui_profile'}.contains(t.id))
            .toList(growable: false),
        'Toggle in Settings only': all
            .where((t) => t.kind == ToggleKind.readOnly)
            .toList(growable: false),
      };
}
