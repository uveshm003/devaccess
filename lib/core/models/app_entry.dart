import 'package:flutter/foundation.dart';

/// FR-APP-1 — one row in the apps inspector.
@immutable
class AppEntry {
  const AppEntry({
    required this.package,
    required this.label,
    required this.versionName,
    required this.versionCode,
    required this.targetSdk,
    required this.minSdk,
    required this.system,
    required this.debuggable,
    required this.enabled,
    required this.launchable,
    required this.firstInstall,
    required this.lastUpdate,
    required this.installer,
    required this.uid,
  });

  factory AppEntry.fromMap(Map<String, dynamic> m) => AppEntry(
        package: m['package'] as String? ?? '',
        label: m['label'] as String? ?? '',
        versionName: m['versionName'] as String?,
        versionCode: (m['versionCode'] as num?)?.toInt() ?? 0,
        targetSdk: (m['targetSdk'] as num?)?.toInt() ?? 0,
        minSdk: (m['minSdk'] as num?)?.toInt(),
        system: m['system'] == true,
        debuggable: m['debuggable'] == true,
        enabled: m['enabled'] != false,
        launchable: m['launchable'] == true,
        firstInstall: DateTime.fromMillisecondsSinceEpoch((m['firstInstall'] as num?)?.toInt() ?? 0),
        lastUpdate: DateTime.fromMillisecondsSinceEpoch((m['lastUpdate'] as num?)?.toInt() ?? 0),
        installer: m['installer'] as String?,
        uid: (m['uid'] as num?)?.toInt() ?? 0,
      );

  final String package;
  final String label;
  final String? versionName;
  final int versionCode;
  final int targetSdk;
  final int? minSdk;
  final bool system;
  final bool debuggable;
  final bool enabled;
  final bool launchable;
  final DateTime firstInstall;
  final DateTime lastUpdate;
  final String? installer;
  final int uid;

  String get installSource => switch (installer) {
        'com.android.vending' => 'Google Play',
        'com.amazon.venezia' => 'Amazon Appstore',
        'com.google.android.packageinstaller' ||
        'com.android.packageinstaller' =>
          'Package installer (sideload)',
        'org.fdroid.fdroid' => 'F-Droid',
        null => system ? 'Preinstalled' : 'Unknown',
        _ => installer!,
      };

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return label.toLowerCase().contains(q) || package.toLowerCase().contains(q);
  }
}
