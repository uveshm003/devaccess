import 'package:flutter/material.dart';

/// NFR-I18N-1 — every user-facing string lives here rather than inline in a widget.
///
/// English is the only shipped locale (A4), but the app is wired for more: add a subclass,
/// register its locale in [AppStringsDelegate.supportedLocales] and the UI needs no change.
abstract class AppStrings {
  const AppStrings();

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ?? const EnStrings();

  String get appName;
  String get tagline;

  // navigation
  String get navHome;
  String get navLaunchers;
  String get navToggles;
  String get navInfo;
  String get navMore;

  // tiers
  String get accessTier;
  String get tierScreenTitle;
  String get currentTier;
  String get whatEachTierAdds;
  String get howToGet;
  String get unlockT1;
  String get unlockT2;
  String get unlockT2Title;
  String get unlockT2Intro;
  String get copyCommand;
  String get commandCopied;
  String get verifyGrant;
  String get grantVerified;
  String get grantNotFound;
  String get wirelessDebugging;
  String get wirelessDebuggingHelp;
  String get probeRoot;
  String get rootProbeHint;
  String get lockedBadge;
  String get whyLocked;

  // launchers
  String get launchersTitle;
  String get searchLaunchers;
  String get favourites;
  String get noFavourites;
  String get pin;
  String get unpin;
  String get openedVia;
  String get fellBackTo;
  String get launchFailed;
  String get intentTester;
  String get intentTesterHelp;
  String get fire;

  // toggles
  String get togglesTitle;
  String get killAnimations;
  String get restoreAnimations;
  String get demoMode;
  String get undo;
  String get writeApplied;
  String get writeRejected;
  String get confirmWriteTitle;
  String confirmWriteBody(String label, String value);
  String get auditLog;
  String get noWritesYet;
  String get toggleInSettings;

  // info
  String get infoTitle;
  String get searchFields;
  String get copyField;
  String get copySection;
  String get copied;
  String get restrictedByOs;
  String get sectionFailed;
  String get expandAll;
  String get collapseAll;

  // monitor
  String get monitorTitle;
  String get cpu;
  String get memory;
  String get battery;
  String get thermal;
  String get network;
  String get startPersistent;
  String get stopPersistent;
  String get persistentNote;
  String get fpsOverlay;
  String get fpsOverlayNote;
  String get grantOverlay;
  String get samplingInterval;

  // sensors
  String get sensorsTitle;
  String get liveViewer;
  String get selfTest;
  String get startTest;
  String get testPassed;
  String get testInconclusive;
  String get noStream;

  // network
  String get networkTitle;
  String get connection;
  String get wifiDetails;
  String get cellularDetails;
  String get tools;
  String get ping;
  String get traceroute;
  String get dnsLookup;
  String get reachability;
  String get httpTest;
  String get host;
  String get run;
  String get stop;
  String get grantLocationForSsid;

  // apps
  String get appsTitle;
  String get searchApps;
  String get showAllPackages;
  String get appDetails;
  String get permissions;
  String get openApp;
  String get uninstall;

  // report
  String get reportTitle;
  String get generateReport;
  String get format;
  String get redactIdentifiers;
  String get redactNote;
  String get share;
  String get copyToClipboard;
  String get saveToFile;
  String get bugSnippet;
  String get appUnderTest;
  String get savedTo;
  String get saveCancelled;

  // settings
  String get settingsTitle;
  String get appearance;
  String get themeMode;
  String get dynamicColour;
  String get accentColour;
  String get units;
  String get byteUnits;
  String get temperatureUnits;
  String get sampling;
  String get dashboardSections;
  String get backupRestore;
  String get exportSettings;
  String get importSettings;
  String get resetSettings;
  String get about;
  String get privacyNote;

  // shared
  String get retry;
  String get cancel;
  String get close;
  String get ok;
  String get loading;
  String get unavailable;
  String get permissionNeeded;
  String get grant;
  String get refresh;
  String get search;
  String get none;
}

class EnStrings extends AppStrings {
  const EnStrings();

  @override
  String get appName => 'DevAccess';
  @override
  String get tagline => 'Developer options & device insight';

  @override
  String get navHome => 'Home';
  @override
  String get navLaunchers => 'Launchers';
  @override
  String get navToggles => 'Toggles';
  @override
  String get navInfo => 'Device';
  @override
  String get navMore => 'More';

  @override
  String get accessTier => 'Access tier';
  @override
  String get tierScreenTitle => 'Access tiers';
  @override
  String get currentTier => 'Current tier';
  @override
  String get whatEachTierAdds => 'What each tier adds';
  @override
  String get howToGet => 'How to get it';
  @override
  String get unlockT1 => 'Grant "Modify system settings"';
  @override
  String get unlockT2 => 'Unlock T2';
  @override
  String get unlockT2Title => 'Unlock tier T2 over adb';
  @override
  String get unlockT2Intro =>
      'Android never grants WRITE_SECURE_SETTINGS from a permission dialog. One adb command '
      'gives it to DevAccess permanently — until the app is uninstalled.';
  @override
  String get copyCommand => 'Copy command';
  @override
  String get commandCopied => 'Command copied to the clipboard';
  @override
  String get verifyGrant => 'Verify grant';
  @override
  String get grantVerified => 'WRITE_SECURE_SETTINGS is granted — you are on T2.';
  @override
  String get grantNotFound =>
      'Not granted yet. Run the command, then tap Verify again.';
  @override
  String get wirelessDebugging => 'Pair over wireless debugging';
  @override
  String get wirelessDebuggingHelp =>
      'Android 11 and later can run adb without a cable. In Developer options → Wireless '
      'debugging, tap "Pair device with pairing code", then on your computer run '
      '"adb pair <ip>:<port>" with that code, followed by "adb connect <ip>:<port>".';
  @override
  String get probeRoot => 'Probe for root';
  @override
  String get rootProbeHint =>
      'Runs "su -c id". On a rooted device this may raise a superuser prompt.';
  @override
  String get lockedBadge => 'Locked';
  @override
  String get whyLocked => 'Why is this locked?';

  @override
  String get launchersTitle => 'Quick access';
  @override
  String get searchLaunchers => 'Search settings screens and toggles';
  @override
  String get favourites => 'Favourites';
  @override
  String get noFavourites => 'Pin a screen to keep it at the top.';
  @override
  String get pin => 'Pin';
  @override
  String get unpin => 'Unpin';
  @override
  String get openedVia => 'Opened via';
  @override
  String get fellBackTo => 'Primary intent was missing; fell back to';
  @override
  String get launchFailed => 'No activity on this device handles that screen';
  @override
  String get intentTester => 'Intent tester';
  @override
  String get intentTesterHelp =>
      'Fire an arbitrary action or URI to validate a deep link. Available in the off-Play '
      'flavour, or at T2 and above.';
  @override
  String get fire => 'Fire intent';

  @override
  String get togglesTitle => 'Developer toggles';
  @override
  String get killAnimations => 'Kill all animations';
  @override
  String get restoreAnimations => 'Restore animations (1×)';
  @override
  String get demoMode => 'SystemUI demo mode';
  @override
  String get undo => 'Undo';
  @override
  String get writeApplied => 'Applied and verified';
  @override
  String get writeRejected => 'The OS rejected that write';
  @override
  String get confirmWriteTitle => 'Confirm elevated write';
  @override
  String confirmWriteBody(String label, String value) =>
      'Set "$label" to $value? This writes to a protected system setting and is recorded in '
      'the local audit log.';
  @override
  String get auditLog => 'Write audit log';
  @override
  String get noWritesYet => 'No elevated writes recorded yet.';
  @override
  String get toggleInSettings => 'Toggle in Settings';

  @override
  String get infoTitle => 'Device information';
  @override
  String get searchFields => 'Search fields';
  @override
  String get copyField => 'Copy value';
  @override
  String get copySection => 'Copy section';
  @override
  String get copied => 'Copied';
  @override
  String get restrictedByOs => 'Restricted by OS';
  @override
  String get sectionFailed => 'This section could not be read';
  @override
  String get expandAll => 'Expand all';
  @override
  String get collapseAll => 'Collapse all';

  @override
  String get monitorTitle => 'Live monitor';
  @override
  String get cpu => 'CPU';
  @override
  String get memory => 'Memory';
  @override
  String get battery => 'Battery';
  @override
  String get thermal => 'Thermal';
  @override
  String get network => 'Network';
  @override
  String get startPersistent => 'Start background monitor';
  @override
  String get stopPersistent => 'Stop background monitor';
  @override
  String get persistentNote =>
      'Runs a foreground service with an ongoing notification. Sampling pauses while the '
      'screen is off, but a continuous monitor still costs battery.';
  @override
  String get fpsOverlay => 'Frame-time overlay';
  @override
  String get fpsOverlayNote =>
      'Draws FPS and worst frame time on top of every app. Needs the "draw over other apps" '
      'permission.';
  @override
  String get grantOverlay => 'Grant overlay permission';
  @override
  String get samplingInterval => 'Sampling interval';

  @override
  String get sensorsTitle => 'Sensors';
  @override
  String get liveViewer => 'Live values';
  @override
  String get selfTest => 'Self-test';
  @override
  String get startTest => 'Start test';
  @override
  String get testPassed => 'Sensor responded as expected';
  @override
  String get testInconclusive =>
      'No clear response — the sensor may be broken, or the movement was too small.';
  @override
  String get noStream => 'This sensor reports on a trigger, so there is no stream to graph.';

  @override
  String get networkTitle => 'Network';
  @override
  String get connection => 'Connection';
  @override
  String get wifiDetails => 'Wi-Fi';
  @override
  String get cellularDetails => 'Cellular';
  @override
  String get tools => 'Tools';
  @override
  String get ping => 'Ping';
  @override
  String get traceroute => 'Traceroute';
  @override
  String get dnsLookup => 'DNS lookup';
  @override
  String get reachability => 'Reachability';
  @override
  String get httpTest => 'HTTP latency';
  @override
  String get host => 'Host';
  @override
  String get run => 'Run';
  @override
  String get stop => 'Stop';
  @override
  String get grantLocationForSsid =>
      'Grant location to read the Wi-Fi SSID and BSSID (Android requires it since 8.1).';

  @override
  String get appsTitle => 'Apps';
  @override
  String get searchApps => 'Search apps';
  @override
  String get showAllPackages => 'Show every installed package';
  @override
  String get appDetails => 'App details';
  @override
  String get permissions => 'Permissions';
  @override
  String get openApp => 'Open app';
  @override
  String get uninstall => 'Uninstall';

  @override
  String get reportTitle => 'Report & export';
  @override
  String get generateReport => 'Generate report';
  @override
  String get format => 'Format';
  @override
  String get redactIdentifiers => 'Redact identifiers';
  @override
  String get redactNote =>
      'Masks the fingerprint, serial, IP addresses, SSID/BSSID and carrier codes.';
  @override
  String get share => 'Share';
  @override
  String get copyToClipboard => 'Copy';
  @override
  String get saveToFile => 'Save to file';
  @override
  String get bugSnippet => 'Bug-report snippet';
  @override
  String get appUnderTest => 'App under test (optional)';
  @override
  String get savedTo => 'Saved';
  @override
  String get saveCancelled => 'Save cancelled';

  @override
  String get settingsTitle => 'Settings';
  @override
  String get appearance => 'Appearance';
  @override
  String get themeMode => 'Theme';
  @override
  String get dynamicColour => 'Dynamic colour (Android 12+)';
  @override
  String get accentColour => 'Accent colour';
  @override
  String get units => 'Units';
  @override
  String get byteUnits => 'Byte units';
  @override
  String get temperatureUnits => 'Temperature';
  @override
  String get sampling => 'Sampling';
  @override
  String get dashboardSections => 'Home dashboard sections';
  @override
  String get backupRestore => 'Backup & restore';
  @override
  String get exportSettings => 'Export settings';
  @override
  String get importSettings => 'Import settings';
  @override
  String get resetSettings => 'Reset everything';
  @override
  String get about => 'About';
  @override
  String get privacyNote =>
      'DevAccess has no backend and no analytics. Nothing leaves this device unless you '
      'explicitly share or export it.';

  @override
  String get retry => 'Retry';
  @override
  String get cancel => 'Cancel';
  @override
  String get close => 'Close';
  @override
  String get ok => 'OK';
  @override
  String get loading => 'Loading…';
  @override
  String get unavailable => 'Unavailable';
  @override
  String get permissionNeeded => 'Permission needed';
  @override
  String get grant => 'Grant';
  @override
  String get refresh => 'Refresh';
  @override
  String get search => 'Search';
  @override
  String get none => 'None';
}

class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppStringsDelegate();

  static const supportedLocales = [Locale('en')];

  @override
  bool isSupported(Locale locale) =>
      supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) async => const EnStrings();

  @override
  bool shouldReload(AppStringsDelegate old) => false;
}
