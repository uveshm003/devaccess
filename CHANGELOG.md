# Changelog

All notable changes to DevAccess are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Backlog items from SRS section 11: logcat viewer behind an adb `READ_LOGS` grant,
wireless-debugging QR pairing helper, feature-flag inspector, scheduled health snapshots,
multi-device report comparison, Tasker/intent automation hooks.

## [1.0.0] — 2026-09-12

Initial public release.

### Added

- **Access tiers** — runtime resolution of T0 base / T1 `WRITE_SETTINGS` / T2
  `WRITE_SECURE_SETTINGS` / T3 root, a locked badge with an explanation wherever the
  current tier falls short, and a guided T2 unlock wizard including Android 11+ wireless
  debugging.
- **Quick access** — ~40 categorised Settings launchers with per-launcher fallback chains,
  favourites, global search across launchers and toggles, and a guarded intent tester.
- **Toggles** — animation scales with presets and kill-all, USB debugging, stay-awake, show
  taps, pointer location, brightness and timeout, force-RTL, don't-keep-activities, process
  limit, GPU debug properties, SystemUI demo mode. Every elevated write is confirmed,
  verified by re-read, and recorded in a local audit log with undo.
- **Device info** — 14 collapsible sections, per-field and per-section copy, live sections
  that refresh while visible.
- **Live monitor** — per-core CPU load and frequency, memory, battery level/temperature/
  voltage/current/estimates, thermal status and zones, network throughput, an optional
  foreground service and an optional FPS overlay.
- **Sensors** — full metadata enumeration, live values with a rolling graph, guided
  self-tests.
- **Network** — connection, Wi-Fi and cellular detail plus ping, traceroute, DNS lookup,
  reachability and HTTP latency.
- **Apps** — launchable-package inspector with versions, SDKs, install source, debuggable
  flag, declared permissions and per-app Settings deep links.
- **Report** — Text, Markdown, JSON and PDF export with PII redaction, share sheet,
  clipboard, SAF save and a bug-report snippet.
- **Surfaces** — 4 Quick Settings tiles, a live home-screen widget and dynamic launcher
  shortcuts.
- **Settings** — Material 3 theming with dynamic colour, unit choices, sampling rates, a
  home-dashboard section picker, backup/restore and the write audit log.
- **Design system** — spacing/radius/motion tokens, a semantic palette that survives any
  Material You accent, an authored neutral ramp, a tuned type scale with tabular figures,
  and a themed component set with predictive-back transitions.
- **Build** — `play` and `foss` flavours differing only where Play policy forces it,
  release signing via a git-ignored `android/key.properties` with a documented debug-key
  fallback, and zero third-party dependencies in Dart or Kotlin.

[Unreleased]: https://github.com/uveshmenpur/devaccess/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/uveshmenpur/devaccess/releases/tag/v1.0.0
