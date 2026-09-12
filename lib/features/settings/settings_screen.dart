import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/strings.dart';
import '../../core/state/app_settings.dart';
import '../../core/state/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/util/formatters.dart';
import '../../widgets/common.dart';
import '../shell/app_shell.dart';
import '../toggles/audit_log_screen.dart';

/// FR-SET-1..4 — appearance, units, sampling, dashboard layout, backup/restore and about.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final services = Services.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.settingsTitle)),
      body: ListenableBuilder(
        listenable: services.settings,
        builder: (context, _) {
          final settings = services.settings;
          return ListView(
            padding: const EdgeInsets.only(bottom: Insets.scrollBottom),
            children: [
              SectionHeader(strings.appearance),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.brightness_6_outlined),
                      title: Text(strings.themeMode),
                      trailing: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode)),
                          ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto)),
                          ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode)),
                        ],
                        selected: {settings.themeMode},
                        showSelectedIcon: false,
                        onSelectionChanged: (v) => settings.setThemeMode(v.first),
                      ),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.palette_outlined),
                      title: Text(strings.dynamicColour),
                      subtitle: const Text(
                        'Seeds the theme from the wallpaper palette where Android exposes it.',
                      ),
                      value: settings.dynamicColour,
                      onChanged: settings.setDynamicColour,
                    ),
                    ListTile(
                      leading: const Icon(Icons.color_lens_outlined),
                      title: Text(strings.accentColour),
                      subtitle: Text(
                        settings.dynamicColour
                            ? 'Only used where Android has no wallpaper palette to offer.'
                            : 'Seeds every colour in the app.',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Insets.md, 0, Insets.md, Insets.md),
                      child: _AccentPicker(settings: settings),
                    ),
                  ],
                ),
              ),
              SectionHeader(strings.units),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.data_usage),
                      title: Text(strings.byteUnits),
                      subtitle: Text(settings.byteUnit.label),
                      trailing: SegmentedButton<ByteUnit>(
                        segments: const [
                          ButtonSegment(value: ByteUnit.binary, label: Text('MiB')),
                          ButtonSegment(value: ByteUnit.decimal, label: Text('MB')),
                        ],
                        selected: {settings.byteUnit},
                        showSelectedIcon: false,
                        onSelectionChanged: (v) => settings.setByteUnit(v.first),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.thermostat),
                      title: Text(strings.temperatureUnits),
                      trailing: SegmentedButton<TemperatureUnit>(
                        segments: const [
                          ButtonSegment(value: TemperatureUnit.celsius, label: Text('°C')),
                          ButtonSegment(value: TemperatureUnit.fahrenheit, label: Text('°F')),
                        ],
                        selected: {settings.temperatureUnit},
                        showSelectedIcon: false,
                        onSelectionChanged: (v) => settings.setTemperatureUnit(v.first),
                      ),
                    ),
                  ],
                ),
              ),
              SectionHeader(strings.sampling),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text('${strings.samplingInterval}: ${settings.samplingIntervalMs} ms'),
                      subtitle: Slider(
                        value: settings.samplingIntervalMs.toDouble(),
                        min: 250,
                        max: 5000,
                        divisions: 19,
                        label: '${settings.samplingIntervalMs} ms',
                        onChanged: (v) => settings.setSamplingInterval(v.round()),
                      ),
                    ),
                    ListTile(
                      title: Text('Info refresh: ${settings.infoRefreshMs} ms'),
                      subtitle: Slider(
                        value: settings.infoRefreshMs.toDouble(),
                        min: 500,
                        max: 10000,
                        divisions: 19,
                        label: '${settings.infoRefreshMs} ms',
                        onChanged: (v) {
                          settings.setInfoRefresh(v.round());
                          services.info.refreshInterval = v.round();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SectionHeader('Safety & privacy'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.shield_outlined),
                      title: Text(strings.redactIdentifiers),
                      subtitle: Text(strings.redactNote),
                      value: settings.redactByDefault,
                      onChanged: settings.setRedactByDefault,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.warning_amber_outlined),
                      title: const Text('Confirm elevated writes'),
                      subtitle: const Text(
                        'Ask before writing any protected setting (T2 and above).',
                      ),
                      value: settings.confirmElevatedWrites,
                      onChanged: settings.setConfirmElevatedWrites,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.terminal),
                      title: const Text('Probe for root at startup'),
                      subtitle: const Text(
                        'Runs "su -c id" on launch. Off by default because it can raise a '
                        'superuser prompt.',
                      ),
                      value: settings.probeRootOnStart,
                      onChanged: settings.setProbeRootOnStart,
                    ),
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(strings.auditLog),
                      subtitle: Text('${settings.auditLog.length} recorded writes'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => pushScreen(context, const AuditLogScreen()),
                    ),
                  ],
                ),
              ),
              SectionHeader(strings.dashboardSections),
              const _DashboardSectionPicker(),
              SectionHeader(strings.backupRestore),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.upload_file),
                      title: Text(strings.exportSettings),
                      subtitle: const Text('Favourites, layout and preferences as JSON.'),
                      onTap: () => _export(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.download),
                      title: Text(strings.importSettings),
                      subtitle: const Text('Paste a previously exported backup.'),
                      onTap: () => _import(context),
                    ),
                    ListTile(
                      leading: Icon(Icons.restart_alt,
                          color: Theme.of(context).colorScheme.error),
                      title: Text(strings.resetSettings),
                      onTap: () => _reset(context),
                    ),
                  ],
                ),
              ),
              SectionHeader(strings.about),
              const _AboutCard(),
            ],
          );
        },
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final services = Services.read(context);
    final strings = AppStrings.of(context);
    final json = services.settings.exportJson();
    final result = await services.bridge.saveFile(
      name: 'devaccess-settings.json',
      mime: 'application/json',
      bytes: Uint8List.fromList(utf8.encode(json)),
    );
    if (!context.mounted) return;
    if (result['ok'] != true) {
      // Fall back to the clipboard when no file picker is available.
      await Clipboard.setData(ClipboardData(text: json));
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['ok'] == true ? strings.savedTo : strings.copied),
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    final controller = TextEditingController();
    final strings = AppStrings.of(context);
    final json = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.importSettings),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(hintText: 'Paste the backup JSON here'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(strings.ok),
          ),
        ],
      ),
    );
    controller.dispose();
    if (json == null || json.trim().isEmpty || !context.mounted) return;
    final error = await Services.read(context).settings.importJson(json);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Settings restored')),
    );
  }

  Future<void> _reset(BuildContext context) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.resetSettings),
        content: const Text(
          'This clears favourites, preferences and the local write audit log. It does not '
          'change any device setting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.ok),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await Services.read(context).settings.resetAll();
  }
}

class _AboutCard extends StatefulWidget {
  const _AboutCard();

  @override
  State<_AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<_AboutCard> {
  Map<String, dynamic> _info = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final info = await Services.read(context).bridge.appInfo();
      if (mounted) setState(() => _info = info);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${strings.appName} ${_info['versionName'] ?? ''}',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(strings.tagline, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            SelectableText(
              'Package  ${_info['packageName'] ?? Fmt.dash}\n'
              'Build    ${_info['versionCode'] ?? Fmt.dash} · ${_info['flavor'] ?? Fmt.dash}\n'
              'Android  ${_info['release'] ?? Fmt.dash} (API ${_info['sdkInt'] ?? Fmt.dash})',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(strings.privacyNote, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// FR-SET-2 — choose which device-information sections appear on the home dashboard.
class _DashboardSectionPicker extends StatelessWidget {
  const _DashboardSectionPicker();

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([services.info, services.settings]),
      builder: (context, _) {
        final available = services.info.sections;
        if (available.isEmpty) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.hourglass_empty),
              title: Text('Loading the section list…'),
            ),
          );
        }
        final selected = services.settings.dashboardSections;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final section in available)
                  FilterChip(
                    label: Text(section.title),
                    selected: selected.contains(section.id),
                    onSelected: (on) {
                      final next = selected.toList();
                      if (on) {
                        next.add(section.id);
                      } else {
                        next.remove(section.id);
                      }
                      services.settings.setDashboardSections(next);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}


/// The accent swatches. Dimmed while dynamic colour is on, because the wallpaper palette
/// wins there — a control that silently does nothing is worse than one that says so.
class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final selected = settings.accent.toARGB32();
    return Opacity(
      opacity: settings.dynamicColour ? 0.55 : 1,
      child: Wrap(
        spacing: Insets.sm,
        runSpacing: Insets.sm,
        children: [
          for (final entry in AppTheme.accents.entries)
            Tooltip(
              message: entry.key,
              child: Semantics(
                button: true,
                selected: selected == entry.value.toARGB32(),
                label: entry.key,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => settings.setAccent(entry.value),
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: entry.value,
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: selected == entry.value.toARGB32() ? 2.5 : 1,
                        color: selected == entry.value.toARGB32()
                            ? context.scheme.onSurface
                            : context.palette.hairline,
                      ),
                    ),
                    child: selected == entry.value.toARGB32()
                        // The swatches span mint to slate; pick the tick colour that
                        // actually reads on each one.
                        ? Icon(
                            Icons.check_rounded,
                            size: 17,
                            color: ThemeData.estimateBrightnessForColor(entry.value) ==
                                    Brightness.dark
                                ? Colors.white
                                : Colors.black87,
                          )
                        : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
