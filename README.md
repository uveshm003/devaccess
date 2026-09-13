# DevAccess

**Developer options & device insight hub — Flutter + Kotlin, Android.**

[![CI](https://github.com/uveshmenpur/devaccess/actions/workflows/ci.yml/badge.svg)](https://github.com/uveshmenpur/devaccess/actions/workflows/ci.yml)
[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Platform: Android 7.0+](https://img.shields.io/badge/platform-Android%207.0%2B-3ddc84.svg)](#build)
[![Dependencies: none](https://img.shields.io/badge/dependencies-none-success.svg)](#dependencies)

One-tap access to every Android Settings screen, an exhaustive device-information
dashboard, live hardware monitoring and on-device diagnostics — implemented against
`requirement.md` (SRS v1.0).

No backend, no accounts, no analytics, no third-party dependencies.

---

## Access tiers

Android will not let an ordinary app flip developer settings, so DevAccess is layered.
The app resolves the highest available tier at runtime and adapts every control.

| Tier | Obtained by | Unlocks |
|------|-------------|---------|
| **T0** Base | nothing | Deep-link launchers, the full read-only dashboard, diagnostics, monitors, reporting |
| **T1** System settings | user grants `WRITE_SETTINGS` in Settings | `Settings.System` writes — brightness, screen timeout, auto-rotate |
| **T2** Secure settings | `adb shell pm grant com.devaccess.app android.permission.WRITE_SECURE_SETTINGS` | Animation scales, `adb_enabled`, stay-awake, show-touches, pointer location, demo mode |
| **T3** Root | rooted device, `su` returns uid 0 | Everything in T2 plus `setprop` and keys the content provider still refuses |

Anything the current tier cannot do renders a **locked badge** with a one-tap explanation
and, where one exists, a deep link to the Settings screen that can do it. Nothing is
hidden and nothing fails silently.

The **Unlock T2 wizard** (More → Access tiers) detects the package name, shows the exact
copy-paste command, walks through Android 11+ wireless-debugging pairing, and verifies the
grant afterwards.

---

## What is in the app

| Area | Highlights |
|------|-----------|
| **Quick access** | ~40 categorised launchers with per-launcher fallback chains, favourites/pinning, global search across launchers *and* toggles, guarded intent tester |
| **Toggles** | Animation scales with presets and a one-tap kill-all, USB debugging, stay-awake, show taps, pointer location, brightness/timeout, force-RTL, don't-keep-activities, process limit, GPU debug props, SystemUI demo mode |
| **Device info** | 14 collapsible sections, every field copyable, every section copyable as a block, live sections refreshing while visible |
| **Live monitor** | Per-core CPU load and frequency, memory, battery (level/temp/voltage/current/estimates), thermal status and zones, up/down throughput, optional foreground service, optional FPS overlay |
| **Sensors** | Full metadata enumeration, live values with a rolling graph, guided self-tests with pass/observed feedback |
| **Network** | Connection/Wi-Fi/cellular detail, ping, traceroute, DNS lookup, reachability, HTTP latency |
| **Apps** | Launchable-package inspector with versions, SDKs, install source, debuggable flag, declared permissions and per-app Settings deep links |
| **Report** | Text / Markdown / JSON / PDF, PII redaction, share sheet, clipboard, SAF save, bug-report snippet |
| **Surfaces** | 4 Quick Settings tiles, a live home-screen widget, dynamic launcher shortcuts |
| **Settings** | Material 3 theming with dynamic colour, unit choices, sampling rates, home-dashboard section picker, backup/restore, write audit log |

---

## Design system

The app is themed end-to-end rather than left on the framework defaults, and every screen
draws from the same small set of tokens.

| Piece | Where | What it fixes |
|-------|-------|---------------|
| **Tokens** | `lib/core/theme/app_tokens.dart` | One spacing scale (`Insets`), one radius scale (`Corners`), one motion scale (`Motion`). Screens pick from these instead of inventing numbers. |
| **Semantic palette** | `AppPalette` theme extension | success / warning / danger / info that stay meaningful whatever accent the user (or Material You) picks — a battery at 4% must not read "fine" because the accent is green. `forLoad()` maps a 0‑1 utilisation to the right one. |
| **Neutral ramp** | `AppTheme._ramp` | `ColorScheme.fromSeed` bleeds seed chroma into every grey. The ramp replaces the surfaces with authored cool neutrals, then blends 2‑7% of the accent back in so a wallpaper palette still reads as one system. |
| **Type scale** | `AppTheme._type` | Negative tracking and heavier weights on display/headline, comfortable line height on body, tabular figures on every live number so digits do not jitter as they change. |
| **Components** | `AppTheme._build` | App bar, cards, nav bar/rail, inputs, chips, buttons, dialogs, sheets, tooltips, sliders, snackbars — plus predictive-back page transitions on Android. |
| **Surface rule** | everywhere | Cards are flat with a 1px hairline instead of a shadow: shadows vanish in dark mode and turn a stack of cards to mush in light mode. |

Shared widgets live in `lib/widgets/`: `AppCard`, `StatTile`, `Pill`, `SectionHeader`,
`EmptyState`, `SearchBox`, `StatusDot` (breathes only while something is genuinely
sampling), `Skeleton`, `MonoText`, `FadeIn` (which collapses to a plain child when the
platform asks for reduced motion), and `AppMark` / `AppWordmark`.

### Brand

The mark is a terminal prompt, `>_`, drawn three times from one geometry: as a
`CustomPainter` in `lib/widgets/brand.dart`, as the Android adaptive icon (with a
`monochrome` layer for Android 13 themed icons), and as the splash vector. Regenerate the
raster icons — the legacy `mipmap-*` set and the 512px Play listing icon — after changing it:

```bash
python3 tool/generate_launcher_icons.py   # needs Pillow
```

The cold-start path is themed too: `values-v31/styles.xml` uses the Android 12+ splash-screen
API, older releases get a matching `launch_background` layer-list, and `NormalTheme` paints
the app's own surface colour so there is no white flash before the first Flutter frame.

### Reviewing the UI without a device

`test/preview_capture.dart` renders real screens against a canned bridge and writes PNGs:

```bash
PREVIEW_OUT=build/preview flutter test test/preview_capture.dart --plain-name "home dark"
```

It is not a `*_test.dart` file, so `flutter test` never picks it up.

---

## Architecture

```
lib/
  core/
    platform/channels.dart     the whole Dart→native contract, failure-tolerant
    models/                    info fields, tiers, launchers, toggles, samples, sensors, apps
    state/                     capability/tier service + data controllers (ChangeNotifier)
    util/                      formatters, report builder
    theme/                     design tokens, semantic palette, the themed component set
    l10n/                      externalised strings + delegate
  data/                        launcher and toggle catalogues (Appendix A / FR-TG)
  features/                    one folder per screen
  widgets/                     brand mark, locked badge, copyable field, sparkline, shared chrome

tool/generate_launcher_icons.py  regenerates the raster launcher + store icons
store/                           Play listing assets

android/app/src/main/kotlin/com/devaccess/app/
  bridge/                      Channels, MethodRouter, stream handlers
  info/                        one provider per dashboard section
  settings/                    Capabilities (tier resolution) + SettingsGateway (read/write)
  security/                    root detection, emulator detection
  intents/  apps/  net/        launcher chains, package inspector, network tools
  monitor/                     sampling engine, foreground service, FPS overlay
  surface/                     TileServices, AppWidgetProvider, ShortcutManager
  report/  util/               exporter + PDF renderer, prefs, system helpers
```

**T-ARCH-3** — a capability service resolves what is possible at runtime, a data layer of
independently-failable providers reads the device, and the presentation layer renders
locked/available state from capability results.

### Platform channels

Method channels carry everything Dart cannot reach on its own; three event channels carry
the streaming surfaces.

| Channel | Purpose |
|---------|---------|
| `dev.access/method` | request/response: tier, settings read+write, intents, info sections, apps, network one-shots, exports, surfaces, prefs |
| `dev.access/events/monitor` | one telemetry sample per interval |
| `dev.access/events/sensors` | live sensor values for one sensor type |
| `dev.access/events/net` | ping / traceroute output, line by line |

Every native handler is wrapped: a platform failure returns a structured error that the UI
renders as a labelled "unavailable" state rather than throwing (**NFR-RELIABILITY-1**).
Slow work (GPU probe, camera enumeration, package listing, network tools) runs on a
background executor so the platform thread never blocks.

### Dependencies

None. `pubspec.yaml` declares only `flutter` and `flutter_lints`. Graphs are
`CustomPainter`, the brand mark and launcher icons are drawn rather than bundled, the type
scale is tuned platform text rather than a shipped font, preferences are a JSON blob through
the bridge, and sharing and file saving go through native intents and the Storage Access
Framework. This keeps the app offline-first
with no backend and no third-party code (**G6**, **NFR-PRIV-1**).

---

## Build

```bash
flutter pub get
flutter test
flutter analyze

# Play-policy build (default): no QUERY_ALL_PACKAGES, intent tester gated behind T2
flutter build apk --flavor play

# Off-Play build: full package visibility, intent tester always available
flutter build apk --flavor foss     # applicationId com.devaccess.app.foss
```

Min SDK 24 (Android 7.0), target SDK = Flutter's current default (36).

### Flavours

`play` and `foss` differ only where Play policy forces them to (**C6 / A2**). The
`QUERY_ALL_PACKAGES` declaration lives solely in `android/app/src/foss/AndroidManifest.xml`,
and `BuildConfig.FULL_ACCESS` gates the free-form intent tester and the full package list.
When a capability is missing, the UI says exactly why instead of hiding the control.

### Release signing

A release build needs a keystore. Generate one and point `android/key.properties` at it:

```bash
keytool -genkey -v -keystore ~/devaccess-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias devaccess

cp android/key.properties.example android/key.properties   # then fill it in
```

Both `key.properties` and `*.jks` / `*.keystore` are covered by `android/.gitignore`.
Keep an off-machine backup of the keystore: Play ties a listing to its signing key, and
losing it means never shipping an update to that listing again.

Without `key.properties` the release build still succeeds — it falls back to the debug
keys so `flutter run --release` works on a fresh clone — but it logs

```
DevAccess: android/key.properties not found — signing the release build with the debug
keys. This APK/AAB cannot be distributed.
```

Check which key actually signed an artifact before you upload it:

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-play-release.apk
```

---

## Platform limits that are surfaced, not hidden

These are Android security realities, and the app reports them verbatim rather than
faking a value (**FR-INFO-3**, section 10 of the SRS):

- **IMEI / serial** — needs `READ_PRIVILEGED_PHONE_STATE`; unavailable to any normal app
  from API 29. Shown as *Restricted by OS* with that reason.
- **Wi-Fi SSID / BSSID** — needs location permission *and* location services on, from API
  27/28. The Wi-Fi screen offers the grant in context.
- **Device MAC** — randomised and unreadable since API 23.
- **`/proc/stat`, `/sys/class/thermal`, `cpufreq`** — restricted on many builds; the CPU
  and thermal views say so instead of showing zeros.
- **Play Integrity** — needs a Cloud project and a server-side verdict check. DevAccess
  ships no backend, so it reports verified-boot state and root detection instead.
- **Design capacity, cycle count** — hidden framework resources; reported as restricted
  where the OEM does not expose a readable node.
- **Mock location, OEM unlocking, default USB config** — no writable key and no adb path,
  so DevAccess deep-links to the Settings toggle rather than pretending to own it.
- **Full logcat** — needs `READ_LOGS` via adb; listed in the backlog, not shipped.

---

## Safety and privacy

- No backend, no accounts, no analytics. Nothing leaves the device unless the user shares
  or exports it (**NFR-PRIV-1**).
- Fields that are identifiers are flagged in the UI and masked by the redaction toggle
  before any share (**NFR-PRIV-2**).
- Every elevated (T2/T3) write asks for confirmation, is verified by re-reading the key,
  and is recorded in a local, reviewable audit log with undo (**NFR-SEC-1**, **FR-TG-8**).
- The app is fully usable with zero runtime permissions granted (**FR-PERM-2**); each one
  is requested in context, immediately before the feature that needs it.

---

## Requirement traceability

| Requirement | Where |
|---|---|
| FR-TIER-1..3 | `settings/Capabilities.kt`, `core/state/tier_controller.dart`, `features/tier/`, `widgets/locked_badge.dart` |
| FR-QA-1..7 | `data/launcher_catalog.dart`, `intents/IntentLauncher.kt`, `features/launchers/` |
| FR-TG-1..8 | `data/toggle_catalog.dart`, `settings/SettingsGateway.kt`, `core/state/toggle_controller.dart`, `features/toggles/` |
| FR-INFO-1..6 | `info/*.kt`, `info/InfoRegistry.kt`, `core/state/info_controller.dart`, `features/info/` |
| FR-MON-1..7 | `monitor/MonitorEngine.kt`, `MonitorService.kt`, `OverlayService.kt`, `features/monitor/` |
| FR-SEN-1..3 | `info/SensorInfo.kt`, `bridge/StreamHandlers.kt`, `features/sensors/` |
| FR-NET-1..5 | `info/NetInfo.kt`, `net/NetTools.kt`, `features/network/` |
| FR-APP-1..3 | `apps/AppsProvider.kt`, `features/apps/` |
| FR-REP-1..4 | `core/util/report_builder.dart`, `report/Exporter.kt`, `features/report/` |
| FR-SURF-1..3 | `surface/Tiles.kt`, `StatsWidgetProvider.kt`, `Shortcuts.kt` |
| FR-SET-1..4 | `core/state/app_settings.dart`, `core/theme/`, `core/l10n/`, `features/settings/` |
| FR-PERM-1..2 | `bridge/MethodRouter.kt` (`perm.*`), contextual prompts in the Wi-Fi, telephony and monitor screens |

---

## Backlog (SRS section 11)

Logcat viewer behind an adb `READ_LOGS` grant · wireless-debugging QR pairing helper ·
feature-flag inspector · scheduled health snapshots · multi-device report comparison ·
Tasker/intent automation hooks.

---

## Contributing

Issues and pull requests are welcome. Start with **[CONTRIBUTING.md](CONTRIBUTING.md)** —
it covers the local setup, the ground rules (no new dependencies, no backend, surface
platform limits rather than faking them) and what a reviewable PR looks like.

- Bugs and feature requests → [open an issue](https://github.com/uveshmenpur/devaccess/issues/new/choose)
- Security vulnerabilities → **[SECURITY.md](SECURITY.md)**, never a public issue
- Release history → [CHANGELOG.md](CHANGELOG.md)
- Participation is governed by the [Code of Conduct](CODE_OF_CONDUCT.md)

---

## License

[Apache License 2.0](LICENSE) — see [NOTICE](NOTICE) for attribution.
