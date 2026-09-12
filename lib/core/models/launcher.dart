import 'package:flutter/material.dart';

/// One link in a fallback chain (NFR-COMPAT-1).
@immutable
class IntentSpec {
  const IntentSpec({
    this.action,
    this.data,
    this.package,
    this.component,
    this.category,
    this.mime,
    this.extras,
  });

  final String? action;
  final String? data;
  final String? package;
  final String? component;
  final String? category;
  final String? mime;
  final Map<String, Object?>? extras;

  Map<String, dynamic> toMap() => {
        if (action != null) 'action': action,
        if (data != null) 'data': data,
        if (package != null) 'package': package,
        if (component != null) 'component': component,
        if (category != null) 'category': category,
        if (mime != null) 'mime': mime,
        if (extras != null) 'extras': extras,
      };

  String get describe => action ?? component ?? data ?? '(empty intent)';
}

enum LauncherCategory {
  developer('Developer', Icons.developer_mode_outlined),
  connectivity('Connectivity', Icons.wifi_outlined),
  display('Display', Icons.brightness_6_outlined),
  sound('Sound', Icons.volume_up_outlined),
  apps('Apps', Icons.apps_outlined),
  security('Security & Privacy', Icons.security_outlined),
  storage('Storage', Icons.sd_storage_outlined),
  system('System', Icons.settings_outlined);

  const LauncherCategory(this.title, this.icon);

  final String title;
  final IconData icon;
}

/// FR-QA-1 — a one-tap deep link into a Settings screen.
@immutable
class LauncherSpec {
  const LauncherSpec({
    required this.id,
    required this.label,
    required this.category,
    required this.chain,
    required this.icon,
    this.description,
    this.synonyms = const [],
    this.minSdk,
  });

  final String id;
  final String label;
  final String? description;
  final LauncherCategory category;

  /// Tried in order; the first that resolves is fired (NFR-COMPAT-1).
  final List<IntentSpec> chain;
  final IconData icon;

  /// FR-QA-6 — extra words the global search should match on.
  final List<String> synonyms;
  final int? minSdk;

  List<Map<String, dynamic>> get chainMaps =>
      chain.map((e) => e.toMap()).toList(growable: false);

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return label.toLowerCase().contains(q) ||
        category.title.toLowerCase().contains(q) ||
        (description?.toLowerCase().contains(q) ?? false) ||
        synonyms.any((s) => s.toLowerCase().contains(q));
  }
}
