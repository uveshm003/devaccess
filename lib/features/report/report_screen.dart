import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/strings.dart';
import '../../core/state/services.dart';
import '../../core/util/formatters.dart';
import '../../core/util/report_builder.dart';
import '../../widgets/common.dart';

/// FR-REP-1..4 — build, preview, redact, share, copy and save the device report.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  ReportFormat _format = ReportFormat.markdown;
  bool _redact = false;
  bool _snippetOnly = false;
  bool _building = true;
  String _content = '';
  Map<String, dynamic> _appInfo = const {};
  final _appUnderTest = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _redact = Services.read(context).settings.redactByDefault;
      await _build();
    });
  }

  @override
  void dispose() {
    _appUnderTest.dispose();
    super.dispose();
  }

  Future<void> _build() async {
    setState(() => _building = true);
    final services = Services.read(context);
    // FR-REP-1 — the report aggregates every section, so make sure they are all loaded.
    await services.info.loadAllProgressively();
    final appInfo = await services.bridge.appInfo();
    if (!mounted) return;
    final sections = services.info.snapshot();
    setState(() {
      _appInfo = appInfo;
      _content = _snippetOnly
          ? ReportBuilder.bugSnippet(
              sections: sections,
              appInfo: appInfo,
              appUnderTest: _appUnderTest.text,
              redact: _redact,
            )
          : ReportBuilder.build(
              format: _format,
              sections: sections,
              appInfo: appInfo,
              redact: _redact,
            );
      _building = false;
    });
  }

  String get _fileName {
    final model = (_appInfo['model'] as String? ?? 'device')
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
        .toLowerCase();
    final stamp = DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '');
    final ext = _snippetOnly ? 'md' : _format.extension;
    return 'devaccess-$model-$stamp.$ext';
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.reportTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: false, label: Text(strings.generateReport)),
                      ButtonSegment(value: true, label: Text(strings.bugSnippet)),
                    ],
                    selected: {_snippetOnly},
                    onSelectionChanged: (v) {
                      setState(() => _snippetOnly = v.first);
                      _build();
                    },
                  ),
                  const SizedBox(height: 14),
                  if (_snippetOnly)
                    TextField(
                      controller: _appUnderTest,
                      decoration: InputDecoration(labelText: strings.appUnderTest),
                      onSubmitted: (_) => _build(),
                    )
                  else ...[
                    Text(strings.format, style: theme.textTheme.labelMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final f in ReportFormat.values)
                          ChoiceChip(
                            label: Text(f.label),
                            selected: _format == f,
                            onSelected: (_) {
                              setState(() => _format = f);
                              _build();
                            },
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _redact,
                    title: Text(strings.redactIdentifiers),
                    subtitle: Text(strings.redactNote),
                    onChanged: (v) {
                      setState(() => _redact = v);
                      _build();
                    },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _building ? null : _share,
                  icon: const Icon(Icons.share, size: 18),
                  label: Text(strings.share),
                ),
                OutlinedButton.icon(
                  onPressed: _building ? null : _copy,
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(strings.copyToClipboard),
                ),
                OutlinedButton.icon(
                  onPressed: _building ? null : _save,
                  icon: const Icon(Icons.save_alt, size: 18),
                  label: Text(strings.saveToFile),
                ),
              ],
            ),
          ),
          SectionHeader(
            'Preview',
            subtitle: _building ? strings.loading : '${_content.length} characters · $_fileName',
          ),
          if (_building)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: LinearProgressIndicator(),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  _content,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              strings.privacyNote,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _bytes() async {
    if (!_snippetOnly && _format == ReportFormat.pdf) {
      final pdf = await Services.read(context)
          .bridge
          .renderPdf(title: 'DevAccess device report', body: _content);
      if (pdf != null) return pdf;
    }
    return Uint8List.fromList(utf8.encode(_content));
  }

  Future<void> _copy() async {
    final strings = AppStrings.of(context);
    await Clipboard.setData(ClipboardData(text: _content));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(strings.copied)));
  }

  Future<void> _share() async {
    final services = Services.read(context);
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!_snippetOnly && _format == ReportFormat.pdf) {
      final bytes = await _bytes();
      await services.bridge.shareFile(
        name: _fileName,
        mime: ReportFormat.pdf.mime,
        bytes: bytes,
        subject: 'DevAccess device report',
      );
      return;
    }
    final result = await services.bridge
        .shareText(_content, subject: 'DevAccess device report');
    if (result['ok'] != true) {
      messenger.showSnackBar(
        SnackBar(content: Text(result['error'] as String? ?? strings.unavailable)),
      );
    }
  }

  /// FR-REP-3 — a user-chosen location, via the Storage Access Framework.
  Future<void> _save() async {
    final services = Services.read(context);
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final bytes = await _bytes();
    final mime = _snippetOnly ? 'text/markdown' : _format.mime;
    final result = await services.bridge.saveFile(
      name: _fileName,
      mime: mime,
      bytes: bytes,
    );
    if (!mounted) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result['ok'] == true
                ? '${strings.savedTo}: ${Fmt.bytes(result['bytes'] as int? ?? bytes.length)}'
                : (result['cancelled'] == true
                    ? strings.saveCancelled
                    : result['error'] as String? ?? strings.unavailable),
          ),
        ),
      );
  }
}
