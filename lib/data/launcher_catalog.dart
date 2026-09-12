import 'package:flutter/material.dart';

import '../core/models/launcher.dart';

/// Appendix A — the deep-link target set (FR-QA-1).
///
/// Every entry carries a fallback chain: OEM skins rename or drop Settings activities, so
/// the launcher walks the chain and falls back to the nearest parent screen rather than
/// failing (NFR-COMPAT-1). Nothing here is a public-API guarantee beyond the first link.
abstract final class LauncherCatalog {
  static const _settings = IntentSpec(action: 'android.settings.SETTINGS');

  static const List<LauncherSpec> all = [
    // ---- Developer ------------------------------------------------------
    LauncherSpec(
      id: 'dev_options',
      label: 'Developer options',
      description: 'The developer options screen itself.',
      category: LauncherCategory.developer,
      icon: Icons.developer_mode,
      synonyms: ['developer', 'debug', 'adb', 'usb debugging', 'oem unlock'],
      chain: [
        IntentSpec(action: 'android.settings.APPLICATION_DEVELOPMENT_SETTINGS'),
        IntentSpec(component: 'com.android.settings/.Settings\$DevelopmentSettingsDashboardActivity'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'settings_root',
      label: 'All settings',
      description: 'The top-level Settings app.',
      category: LauncherCategory.developer,
      icon: Icons.settings,
      synonyms: ['settings', 'root', 'home'],
      chain: [_settings],
    ),
    LauncherSpec(
      id: 'about_phone',
      label: 'About phone (Build number)',
      description: 'Tap Build number seven times to unlock developer options.',
      category: LauncherCategory.developer,
      icon: Icons.info_outline,
      synonyms: ['build number', 'about', 'enable developer options', 'seven taps'],
      chain: [
        IntentSpec(action: 'android.settings.DEVICE_INFO_SETTINGS'),
        IntentSpec(component: 'com.android.settings/.Settings\$MyDeviceInfoActivity'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'running_services',
      label: 'Running services',
      category: LauncherCategory.developer,
      icon: Icons.memory_outlined,
      synonyms: ['processes', 'services', 'memory'],
      chain: [
        IntentSpec(component: 'com.android.settings/.Settings\$DevRunningServicesActivity'),
        IntentSpec(action: 'android.settings.APPLICATION_DEVELOPMENT_SETTINGS'),
        _settings,
      ],
    ),

    // ---- Connectivity ---------------------------------------------------
    LauncherSpec(
      id: 'wireless',
      label: 'Wireless & networks',
      category: LauncherCategory.connectivity,
      icon: Icons.settings_input_antenna,
      synonyms: ['network', 'internet', 'wireless'],
      chain: [
        IntentSpec(action: 'android.settings.WIRELESS_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'wifi',
      label: 'Wi-Fi',
      category: LauncherCategory.connectivity,
      icon: Icons.wifi,
      synonyms: ['wifi', 'wlan', 'ssid', 'access point'],
      chain: [
        IntentSpec(action: 'android.settings.WIFI_SETTINGS'),
        IntentSpec(action: 'android.settings.panel.action.WIFI'),
        IntentSpec(action: 'android.settings.WIRELESS_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'mobile_data',
      label: 'Mobile data & roaming',
      category: LauncherCategory.connectivity,
      icon: Icons.signal_cellular_alt,
      synonyms: ['cellular', 'data', 'roaming', 'sim', 'apn'],
      chain: [
        IntentSpec(action: 'android.settings.DATA_ROAMING_SETTINGS'),
        IntentSpec(action: 'android.settings.NETWORK_OPERATOR_SETTINGS'),
        IntentSpec(action: 'android.settings.WIRELESS_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'bluetooth',
      label: 'Bluetooth',
      category: LauncherCategory.connectivity,
      icon: Icons.bluetooth,
      synonyms: ['bt', 'pairing', 'headset'],
      chain: [
        IntentSpec(action: 'android.settings.BLUETOOTH_SETTINGS'),
        IntentSpec(action: 'android.settings.WIRELESS_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'nfc',
      label: 'NFC',
      category: LauncherCategory.connectivity,
      icon: Icons.nfc,
      synonyms: ['nfc', 'beam', 'tap to pay'],
      chain: [
        IntentSpec(action: 'android.settings.NFC_SETTINGS'),
        IntentSpec(action: 'android.settings.NFCSHARING_SETTINGS'),
        IntentSpec(action: 'android.settings.WIRELESS_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'vpn',
      label: 'VPN',
      category: LauncherCategory.connectivity,
      icon: Icons.vpn_key_outlined,
      synonyms: ['vpn', 'tunnel', 'private network'],
      chain: [
        IntentSpec(action: 'android.settings.VPN_SETTINGS'),
        IntentSpec(action: 'android.net.vpn.SETTINGS'),
        IntentSpec(action: 'android.settings.WIRELESS_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'hotspot',
      label: 'Hotspot & tethering',
      category: LauncherCategory.connectivity,
      icon: Icons.wifi_tethering,
      synonyms: ['tether', 'hotspot', 'usb tethering', 'share connection'],
      chain: [
        IntentSpec(component: 'com.android.settings/.TetherSettings'),
        IntentSpec(component: 'com.android.settings/.Settings\$TetherSettingsActivity'),
        IntentSpec(action: 'android.settings.WIRELESS_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'airplane',
      label: 'Airplane mode',
      category: LauncherCategory.connectivity,
      icon: Icons.airplanemode_active,
      synonyms: ['flight mode', 'aeroplane', 'offline'],
      chain: [
        IntentSpec(action: 'android.settings.AIRPLANE_MODE_SETTINGS'),
        IntentSpec(action: 'android.settings.WIRELESS_SETTINGS'),
        _settings,
      ],
    ),

    // ---- Display --------------------------------------------------------
    LauncherSpec(
      id: 'display',
      label: 'Display',
      category: LauncherCategory.display,
      icon: Icons.brightness_6,
      synonyms: ['screen', 'display', 'refresh rate', 'font size'],
      chain: [
        IntentSpec(action: 'android.settings.DISPLAY_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'brightness',
      label: 'Brightness',
      category: LauncherCategory.display,
      icon: Icons.brightness_medium,
      synonyms: ['brightness', 'adaptive', 'backlight', 'nits'],
      chain: [
        IntentSpec(component: 'com.android.settings/.Settings\$BrightnessSettingsActivity'),
        IntentSpec(action: 'android.settings.DISPLAY_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'daydream',
      label: 'Screensaver',
      category: LauncherCategory.display,
      icon: Icons.nightlight_outlined,
      synonyms: ['daydream', 'screensaver', 'dream'],
      chain: [
        IntentSpec(action: 'android.settings.DREAM_SETTINGS'),
        IntentSpec(action: 'android.settings.DISPLAY_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'auto_rotate',
      label: 'Auto-rotate',
      category: LauncherCategory.display,
      icon: Icons.screen_rotation,
      synonyms: ['rotation', 'orientation', 'auto rotate'],
      minSdk: 31,
      chain: [
        IntentSpec(action: 'android.settings.AUTO_ROTATE_SETTINGS'),
        IntentSpec(action: 'android.settings.DISPLAY_SETTINGS'),
        _settings,
      ],
    ),

    // ---- Sound ----------------------------------------------------------
    LauncherSpec(
      id: 'sound',
      label: 'Sound & vibration',
      category: LauncherCategory.sound,
      icon: Icons.volume_up,
      synonyms: ['volume', 'ringtone', 'vibrate', 'audio'],
      chain: [
        IntentSpec(action: 'android.settings.SOUND_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'dnd',
      label: 'Do Not Disturb',
      category: LauncherCategory.sound,
      icon: Icons.do_not_disturb_on_outlined,
      synonyms: ['dnd', 'zen', 'silence', 'quiet'],
      chain: [
        IntentSpec(action: 'android.settings.ZEN_MODE_SETTINGS'),
        IntentSpec(action: 'android.settings.NOTIFICATION_POLICY_ACCESS_SETTINGS'),
        IntentSpec(action: 'android.settings.SOUND_SETTINGS'),
        _settings,
      ],
    ),

    // ---- Apps -----------------------------------------------------------
    LauncherSpec(
      id: 'all_apps',
      label: 'All apps',
      category: LauncherCategory.apps,
      icon: Icons.apps,
      synonyms: ['applications', 'manage apps', 'installed'],
      chain: [
        IntentSpec(action: 'android.settings.MANAGE_APPLICATIONS_SETTINGS'),
        IntentSpec(action: 'android.settings.APPLICATION_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'default_apps',
      label: 'Default apps',
      category: LauncherCategory.apps,
      icon: Icons.star_outline,
      synonyms: ['default', 'browser', 'launcher', 'assistant'],
      chain: [
        IntentSpec(action: 'android.settings.MANAGE_DEFAULT_APPS_SETTINGS'),
        IntentSpec(action: 'android.settings.MANAGE_APPLICATIONS_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'notification_access',
      label: 'Notification listener access',
      category: LauncherCategory.apps,
      icon: Icons.notifications_active_outlined,
      synonyms: ['notification listener', 'access', 'notifications'],
      chain: [
        IntentSpec(action: 'android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS'),
        IntentSpec(action: 'android.settings.NOTIFICATION_LISTENER_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'usage_access',
      label: 'Usage access',
      category: LauncherCategory.apps,
      icon: Icons.query_stats_outlined,
      synonyms: ['usage stats', 'screen time', 'app usage'],
      chain: [
        IntentSpec(action: 'android.settings.USAGE_ACCESS_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'overlay_access',
      label: 'Draw over other apps',
      category: LauncherCategory.apps,
      icon: Icons.layers_outlined,
      synonyms: ['overlay', 'system alert window', 'floating', 'bubble'],
      chain: [
        IntentSpec(action: 'android.settings.action.MANAGE_OVERLAY_PERMISSION'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'write_settings_access',
      label: 'Modify system settings',
      description: 'The special access that unlocks tier T1.',
      category: LauncherCategory.apps,
      icon: Icons.tune,
      synonyms: ['write settings', 't1', 'system settings access'],
      chain: [
        IntentSpec(action: 'android.settings.action.MANAGE_WRITE_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'battery_optimisation',
      label: 'Battery optimisation',
      category: LauncherCategory.apps,
      icon: Icons.battery_saver_outlined,
      synonyms: ['doze', 'battery optimization', 'unrestricted', 'background'],
      chain: [
        IntentSpec(action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS'),
        IntentSpec(action: 'android.settings.BATTERY_SAVER_SETTINGS'),
        _settings,
      ],
    ),

    // ---- Security & Privacy ---------------------------------------------
    LauncherSpec(
      id: 'security',
      label: 'Security',
      category: LauncherCategory.security,
      icon: Icons.lock_outline,
      synonyms: ['lock screen', 'pin', 'biometrics', 'fingerprint'],
      chain: [
        IntentSpec(action: 'android.settings.SECURITY_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'privacy',
      label: 'Privacy',
      category: LauncherCategory.security,
      icon: Icons.privacy_tip_outlined,
      synonyms: ['privacy', 'permission manager', 'dashboard'],
      chain: [
        IntentSpec(action: 'android.settings.PRIVACY_SETTINGS'),
        IntentSpec(action: 'android.settings.SECURITY_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'location',
      label: 'Location',
      description: 'Location services must be on for Wi-Fi SSID reads (C5).',
      category: LauncherCategory.security,
      icon: Icons.location_on_outlined,
      synonyms: ['gps', 'location', 'ssid', 'scanning'],
      chain: [
        IntentSpec(action: 'android.settings.LOCATION_SOURCE_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'device_info',
      label: 'Device info / About',
      category: LauncherCategory.security,
      icon: Icons.smartphone_outlined,
      synonyms: ['about phone', 'model', 'serial', 'imei'],
      chain: [
        IntentSpec(action: 'android.settings.DEVICE_INFO_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'credentials',
      label: 'Encryption & credentials',
      category: LauncherCategory.security,
      icon: Icons.enhanced_encryption_outlined,
      synonyms: ['certificate', 'credential storage', 'encryption', 'ca'],
      chain: [
        IntentSpec(action: 'android.credentials.INSTALL'),
        IntentSpec(component: 'com.android.settings/.Settings\$EncryptionAndCredentialActivity'),
        IntentSpec(action: 'android.settings.SECURITY_SETTINGS'),
        _settings,
      ],
    ),

    // ---- Storage --------------------------------------------------------
    LauncherSpec(
      id: 'internal_storage',
      label: 'Internal storage',
      category: LauncherCategory.storage,
      icon: Icons.sd_storage_outlined,
      synonyms: ['storage', 'space', 'free space'],
      chain: [
        IntentSpec(action: 'android.settings.INTERNAL_STORAGE_SETTINGS'),
        IntentSpec(action: 'android.settings.MEMORY_CARD_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'storage_manager',
      label: 'Storage manager',
      category: LauncherCategory.storage,
      icon: Icons.cleaning_services_outlined,
      synonyms: ['smart storage', 'free up space', 'cleanup'],
      chain: [
        IntentSpec(action: 'android.settings.STORAGE_MANAGER_SETTINGS'),
        IntentSpec(action: 'android.settings.INTERNAL_STORAGE_SETTINGS'),
        _settings,
      ],
    ),

    // ---- System ---------------------------------------------------------
    LauncherSpec(
      id: 'date_time',
      label: 'Date & time',
      category: LauncherCategory.system,
      icon: Icons.schedule,
      synonyms: ['clock', 'timezone', 'ntp', '24 hour'],
      chain: [
        IntentSpec(action: 'android.settings.DATE_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'locale',
      label: 'Language & input',
      category: LauncherCategory.system,
      icon: Icons.language,
      synonyms: ['language', 'locale', 'region', 'translate'],
      chain: [
        IntentSpec(action: 'android.settings.LOCALE_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'keyboard',
      label: 'Keyboard / input method',
      category: LauncherCategory.system,
      icon: Icons.keyboard_alt_outlined,
      synonyms: ['ime', 'keyboard', 'input method', 'gboard'],
      chain: [
        IntentSpec(action: 'android.settings.INPUT_METHOD_SETTINGS'),
        IntentSpec(action: 'android.settings.LOCALE_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'accessibility',
      label: 'Accessibility',
      category: LauncherCategory.system,
      icon: Icons.accessibility_new,
      synonyms: ['talkback', 'a11y', 'accessibility', 'magnification'],
      chain: [
        IntentSpec(action: 'android.settings.ACCESSIBILITY_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'backup',
      label: 'Backup & reset',
      category: LauncherCategory.system,
      icon: Icons.backup_outlined,
      synonyms: ['backup', 'restore', 'factory reset'],
      chain: [
        IntentSpec(action: 'android.settings.BACKUP_AND_RESET_SETTINGS'),
        IntentSpec(action: 'android.settings.PRIVACY_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'battery',
      label: 'Battery',
      category: LauncherCategory.system,
      icon: Icons.battery_full,
      synonyms: ['battery', 'power', 'charging', 'saver'],
      chain: [
        IntentSpec(action: 'android.intent.action.POWER_USAGE_SUMMARY'),
        IntentSpec(action: 'android.settings.BATTERY_SAVER_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'notifications',
      label: 'Notifications',
      category: LauncherCategory.system,
      icon: Icons.notifications_outlined,
      synonyms: ['notification', 'channels', 'alerts'],
      chain: [
        IntentSpec(action: 'android.settings.NOTIFICATION_SETTINGS'),
        IntentSpec(action: 'android.settings.SOUND_SETTINGS'),
        _settings,
      ],
    ),
    LauncherSpec(
      id: 'cast',
      label: 'Cast / screen mirroring',
      category: LauncherCategory.system,
      icon: Icons.cast,
      synonyms: ['cast', 'mirror', 'wireless display'],
      chain: [
        IntentSpec(action: 'android.settings.CAST_SETTINGS'),
        IntentSpec(action: 'android.settings.WIRELESS_SETTINGS'),
        _settings,
      ],
    ),
  ];

  static LauncherSpec? byId(String id) {
    for (final l in all) {
      if (l.id == id) return l;
    }
    return null;
  }

  static List<LauncherSpec> inCategory(LauncherCategory c) =>
      all.where((l) => l.category == c).toList(growable: false);
}
