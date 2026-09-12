import 'package:flutter/foundation.dart';

/// Section 5 — the four access tiers.
enum AccessTier {
  t0(0, 'T0', 'Base'),
  t1(1, 'T1', 'System settings'),
  t2(2, 'T2', 'Secure settings'),
  t3(3, 'T3', 'Root');

  const AccessTier(this.level, this.code, this.title);

  final int level;
  final String code;
  final String title;

  static AccessTier fromLevel(int level) =>
      AccessTier.values.firstWhere((t) => t.level == level, orElse: () => AccessTier.t0);

  bool operator >=(AccessTier other) => level >= other.level;

  String get howToGet => switch (this) {
        AccessTier.t0 => 'Available to everyone, no setup.',
        AccessTier.t1 => 'Grant "Modify system settings" to DevAccess from Android Settings.',
        AccessTier.t2 => 'Run one adb command to grant WRITE_SECURE_SETTINGS.',
        AccessTier.t3 => 'Requires a rooted device; DevAccess asks su for permission.',
      };

  String get unlocks => switch (this) {
        AccessTier.t0 =>
          'Deep-link launchers to every Settings screen, the full read-only device dashboard, '
              'diagnostics, live monitors and reporting.',
        AccessTier.t1 =>
          'Writing Settings.System values — screen brightness and screen timeout where the '
              'OEM leaves them writable.',
        AccessTier.t2 =>
          'Writing developer and global settings: animation scales, USB debugging flag, '
              'stay-awake, show touches, pointer location and demo mode.',
        AccessTier.t3 =>
          'Everything T2 offers plus writes that go through su — setprop, settings keys the '
              'content provider still refuses, and privileged state reads.',
      };
}

/// The runtime capability snapshot behind FR-TIER-1..3.
@immutable
class TierStatus {
  const TierStatus({
    required this.tier,
    required this.canWriteSystem,
    required this.canWriteSecure,
    required this.hasRoot,
    required this.rootProbed,
    required this.packageName,
    required this.adbCommand,
    required this.adbDumpCommand,
    required this.adbLogsCommand,
    required this.wirelessDebuggingSupported,
    required this.sdkInt,
    required this.flavor,
    required this.fullAccessBuild,
    required this.suBinary,
    required this.magiskArtifacts,
    required this.buildSignals,
    required this.hasDump,
  });

  factory TierStatus.fromMap(Map<String, dynamic> map) => TierStatus(
        tier: AccessTier.fromLevel((map['tier'] as num?)?.toInt() ?? 0),
        canWriteSystem: map['writeSettings'] == true,
        canWriteSecure: map['writeSecureSettings'] == true,
        hasRoot: map['root'] == true,
        rootProbed: map['rootProbed'] == true,
        packageName: map['packageName'] as String? ?? 'com.devaccess.app',
        adbCommand: map['adbCommand'] as String? ?? '',
        adbDumpCommand: map['adbDumpCommand'] as String? ?? '',
        adbLogsCommand: map['adbLogsCommand'] as String? ?? '',
        wirelessDebuggingSupported: map['wirelessDebuggingSupported'] == true,
        sdkInt: (map['sdkInt'] as num?)?.toInt() ?? 0,
        flavor: map['flavor'] as String? ?? 'play',
        fullAccessBuild: map['fullAccessBuild'] == true,
        suBinary: map['suBinary'] as String?,
        magiskArtifacts:
            (map['magiskArtifacts'] as List?)?.map((e) => e.toString()).toList(growable: false) ??
                const [],
        buildSignals:
            (map['buildSignals'] as List?)?.map((e) => e.toString()).toList(growable: false) ??
                const [],
        hasDump: map['dump'] == true,
      );

  static const unknown = TierStatus(
    tier: AccessTier.t0,
    canWriteSystem: false,
    canWriteSecure: false,
    hasRoot: false,
    rootProbed: false,
    packageName: 'com.devaccess.app',
    adbCommand: '',
    adbDumpCommand: '',
    adbLogsCommand: '',
    wirelessDebuggingSupported: false,
    sdkInt: 0,
    flavor: 'play',
    fullAccessBuild: false,
    suBinary: null,
    magiskArtifacts: [],
    buildSignals: [],
    hasDump: false,
  );

  final AccessTier tier;
  final bool canWriteSystem;
  final bool canWriteSecure;
  final bool hasRoot;
  final bool rootProbed;
  final String packageName;
  final String adbCommand;
  final String adbDumpCommand;
  final String adbLogsCommand;
  final bool wirelessDebuggingSupported;
  final int sdkInt;
  final String flavor;
  final bool fullAccessBuild;
  final String? suBinary;
  final List<String> magiskArtifacts;
  final List<String> buildSignals;
  final bool hasDump;

  bool allows(AccessTier required) => tier.level >= required.level;

  /// Root can write anything the lower tiers can, so T3 satisfies a T1/T2 requirement.
  bool canWriteScope(String scope) =>
      hasRoot || (scope == 'system' ? canWriteSystem : canWriteSecure);

  bool get rootCapable => suBinary != null || magiskArtifacts.isNotEmpty;
}
