# DevAccess — Software Requirements Specification

**Product:** DevAccess — Developer Options & Device Insight Hub
**Platform:** Android (Flutter)
**Document type:** Requirements specification (functional + non-functional)
**Status:** Draft v1.0

---

## 1. Summary

DevAccess is a Flutter Android application that gives developers, QA engineers, and power users one-tap access to Android's developer options and system settings, a deep device-information dashboard, live hardware monitoring, and on-device diagnostics — without hunting through nested Settings menus.

Because Android deliberately prevents ordinary apps from flipping most developer/secure settings, the product is layered into **access tiers**. The base tier works for everyone with zero special setup (deep-linking into the right Settings screens + reading device state). Higher tiers progressively unlock *actual* toggling for users who grant elevated access (`WRITE_SETTINGS`, `WRITE_SECURE_SETTINGS` via adb, or root). Every feature degrades gracefully: anything the current tier can't do is shown in a clearly labeled locked state with instructions to unlock it.

---

## 2. Goals and non-goals

### 2.1 Goals
- **G1** — Reduce the taps needed to reach any developer option or system settings screen to one.
- **G2** — Surface the widest practical set of device information in one place, readable and shareable.
- **G3** — Let power users *toggle* the most common developer settings once they've granted elevated access.
- **G4** — Provide live, low-overhead monitoring of CPU, RAM, battery, thermal, and network state.
- **G5** — Generate a complete, shareable device report suitable for bug tickets.
- **G6** — Ship a clean, offline-first, privacy-respecting app with no backend dependency.

### 2.2 Non-goals
- Not a root-management or Magisk-module tool.
- Not a benchmarking suite (though it exposes raw metrics).
- Not a system-level replacement for the Settings app.
- Does not claim to bypass Android's security model — it works *within* the permission tiers Android allows.

---

## 3. Target users and assumptions

**Personas:** mobile app developers, QA/test engineers, device-lab operators, ROM/firmware enthusiasts, and technically literate power users.

**Assumptions (stated, to be confirmed):**
- **A1** — Minimum supported: Android 7.0 (API 24); target: latest stable API. Rationale: covers the vast majority of active dev/test devices while keeping modern intent and permission APIs available.
- **A2** — Distribution is expected both on-Play and off-Play (sideload/internal), because some capabilities (broad app querying, adb-grant guidance) are easier off-Play. The app must be Play-policy-compliant in its default configuration.
- **A3** — No user accounts, no server, no analytics that transmit device data off-device by default.
- **A4** — English first, with the architecture ready for localization.

---

## 4. Platform constraints (critical — shapes every requirement)

These are Android security realities, not product decisions. The requirements below are written to respect them.

- **C1** — A normal app **cannot** programmatically toggle developer options or secure/global settings. Those require `WRITE_SECURE_SETTINGS`, which is **not** grantable via the runtime permission dialog — only via `adb`, a system/privileged signature, or root.
- **C2** — A normal app **can** deep-link (fire an intent) into virtually any Settings screen, including the Developer Options screen itself. This is the backbone of the base tier.
- **C3** — `WRITE_SETTINGS` (a special access users grant in Settings) allows changing a **small** set of `Settings.System` values (e.g., screen brightness, some system prefs) — it does **not** cover developer options.
- **C4** — Hardware identifiers (IMEI, serial) are restricted from API 29+; the app must not promise them and must show them as "restricted by OS" where unavailable.
- **C5** — Reading Wi-Fi SSID/BSSID requires location permission (and location services enabled) from API 27/28+.
- **C6** — Listing all installed apps requires `QUERY_ALL_PACKAGES`, which is Play-policy-restricted; the default build lists only launchable/relevant packages, with full listing behind an off-Play flavor or explicit justification.
- **C7** — Reading system logcat (`READ_LOGS`) is a signature/privileged permission; a normal app can read only its own logs unless granted via adb.
- **C8** — Quick Settings tiles, home-screen widgets, and app shortcuts require native Android (Kotlin) implementations bridged to Flutter — they are not pure-Dart.

---

## 5. Access tiers

The app detects the highest available tier at runtime and adapts the UI accordingly.

| Tier | Name | How it's obtained | What it unlocks |
|------|------|-------------------|-----------------|
| **T0** | Base | Default, no setup | Deep-link launchers to all Settings screens; full read-only device info; diagnostics; reporting; live monitors |
| **T1** | System settings | User grants `WRITE_SETTINGS` in-app | Toggling of `Settings.System` values (e.g., screen brightness, screen timeout where writable) |
| **T2** | Secure settings | User runs one `adb` command to grant `WRITE_SECURE_SETTINGS` | Toggling of developer/global settings: USB debugging flag, animation scales, stay-awake, show touches/pointer location, demo mode, and similar |
| **T3** | Root | Device is rooted; app requests su | Everything in T2 plus properties/toggles that need root (e.g., `settings`/`setprop` writes, reading privileged state) |

- **FR-TIER-1** — On first run and on demand, the app must detect and display the current tier and clearly list what each higher tier would add.
- **FR-TIER-2** — The app must provide a guided **"Unlock T2"** wizard: detect package name, show the exact copy-paste command (`adb shell pm grant <package> android.permission.WRITE_SECURE_SETTINGS`), link to wireless-debugging pairing instructions (Android 11+), and verify the grant afterward.
- **FR-TIER-3** — Every actionable control must render a **locked badge** with a one-tap explanation when the current tier can't perform it, instead of hiding it or failing silently.

---

## 6. Functional requirements

### 6.1 Quick-access launcher hub (FR-QA)
A searchable, categorized grid/list of shortcuts that fire intents into Settings screens. Works at T0 for all users.

- **FR-QA-1** — Provide one-tap launchers for at minimum the settings screens in Appendix A, grouped into categories (Developer, Connectivity, Display, Sound, Apps, Security & Privacy, Storage, System).
- **FR-QA-2** — Provide a top-level **"Open Developer Options"** action (`ACTION_APPLICATION_DEVELOPMENT_SETTINGS`), with a fallback that opens the main Settings and, on devices where dev options are hidden, guides the user to enable them (tap Build number ×7).
- **FR-QA-3** — Detect and display whether Developer Options and USB debugging are currently enabled (both are readable via `Settings.Global`).
- **FR-QA-4** — Per-app deep links: launch **"App details"** (`ACTION_APPLICATION_DETAILS_SETTINGS`) for any installed/launchable package the user selects.
- **FR-QA-5** — Support **favorites/pinning** so frequently used screens surface at the top.
- **FR-QA-6** — Support **global search** across all launchers and toggles by name and synonym (e.g., "animation" finds the three animation-scale controls).
- **FR-QA-7** — Provide an **intent/deep-link tester**: let advanced users fire a custom action/URI to validate deep links (guarded, off-Play flavor or T2+).

### 6.2 Developer toggles (FR-TG)
Actual switches for developer/system settings, active per tier. Each shows current value read-only at T0 and becomes writable at the tier noted.

- **FR-TG-1** — **Animation scales** (window, transition, animator): read at T0, write at T2. Presets (Off / 0.5× / 1× / 2×) and a "kill all animations" one-tap.
- **FR-TG-2** — **USB debugging flag** (`ADB_ENABLED`): read at T0, write at T2 (where the OS permits).
- **FR-TG-3** — **Stay awake while charging** (`STAY_ON_WHILE_PLUGGED_IN`): read at T0, write at T2.
- **FR-TG-4** — **Show touches / pointer location** (`SHOW_TOUCHES`, `POINTER_LOCATION`): read at T0, write at T2.
- **FR-TG-5** — **Demo mode** (SysUI demo): enable/disable at T2 with a clean status-bar preset for screenshots.
- **FR-TG-6** — **Screen brightness / timeout** (`Settings.System`): write at T1 where the value is writable.
- **FR-TG-7** — **Force RTL, don't-keep-activities, background-process-limit, GPU/rendering debug flags, mock-location app**: exposed as read + launcher at T0 (deep-link to the exact toggle where possible), writable only where the underlying key permits at T2/T3; otherwise clearly marked "toggle in Settings."
- **FR-TG-8** — Every write must be reversible with an in-app **undo** and must re-read and reflect the actual post-write value (never assume success).

### 6.3 Device information dashboard (FR-INFO)
Read-only, exhaustive, grouped, searchable, each field long-press-to-copy. See Appendix B for the full catalog. Requirements below define the categories and behavior.

- **FR-INFO-1** — Present device info in collapsible sections: **Device & Build, OS & Security, Display, SoC/CPU, GPU, Memory, Storage, Battery, Thermal, Network, Telephony, Sensors, Cameras, System state.**
- **FR-INFO-2** — Every field must be individually copyable; every section must be copyable as a block.
- **FR-INFO-3** — Fields unavailable due to OS restriction (C4/C5) must render as "Restricted by OS" with a short reason, not blank or fake.
- **FR-INFO-4** — Values that change (battery, memory, thermal, network) must refresh live while their section is visible, at a user-configurable interval.
- **FR-INFO-5** — Provide **root / bootloader / integrity** status: root detected, su/Magisk presence, bootloader unlock state, verified-boot state, SELinux mode, encryption state, and Play Integrity/basic attestation result where obtainable.
- **FR-INFO-6** — Provide **emulator detection** (flag whether the app is running on an emulator/virtual device).

### 6.4 Live monitoring (FR-MON)
A real-time dashboard with lightweight graphs.

- **FR-MON-1** — Live **CPU**: per-core frequency and load where readable, core count, governor, big/LITTLE clustering.
- **FR-MON-2** — Live **memory**: used/available/total RAM, low-memory flag, per-app memory of DevAccess itself.
- **FR-MON-3** — Live **battery**: level, charge/discharge state, plug type, temperature, voltage, current (mA), estimated charge/discharge rate.
- **FR-MON-4** — Live **thermal**: system thermal status (API 29+) and available thermal-zone temperatures.
- **FR-MON-5** — Live **network throughput**: up/down bytes-per-second (total and per-DevAccess where available).
- **FR-MON-6** — Optional **on-screen FPS/frame-time overlay** (requires overlay permission; gated behind an explicit opt-in).
- **FR-MON-7** — Monitors run in a foreground service only while active, with a configurable sampling rate and a clear battery-impact note; they must stop cleanly when dismissed.

### 6.5 Sensors explorer (FR-SEN)
- **FR-SEN-1** — Enumerate all device sensors with metadata: name, vendor, type, version, resolution, max range, power draw, min delay, reporting mode.
- **FR-SEN-2** — Provide a **live viewer** for readable sensors (accelerometer, gyroscope, magnetometer, proximity, light, pressure, step counter, etc.) with numeric readout and a rolling mini-graph.
- **FR-SEN-3** — Provide simple, self-contained **sensor self-tests** (e.g., "move the device" for accelerometer, "cover the sensor" for proximity/light) with pass/observed feedback.

### 6.6 Network & connectivity tools (FR-NET)
- **FR-NET-1** — Show current connection: type (Wi-Fi/cellular/Ethernet/VPN), is-connected, is-metered.
- **FR-NET-2** — Wi-Fi details (with location permission): SSID/BSSID, RSSI, link speed, frequency/band, channel, IPv4/IPv6, gateway, DNS, subnet, randomized MAC state.
- **FR-NET-3** — Cellular details (where permitted): network generation (5G/LTE/…), carrier, MCC/MNC, roaming state, signal strength, data state.
- **FR-NET-4** — Built-in tools: **ping, traceroute, DNS lookup, reachability check**, and a basic **HTTP/latency test**. (Speed test optional; must be clearly opt-in as it uses data.)
- **FR-NET-5** — Launchers to VPN, Wi-Fi, mobile-data/roaming, hotspot, and airplane-mode settings screens.

### 6.7 Apps inspector (FR-APP)
- **FR-APP-1** — List launchable apps by default (package name, version, target/min SDK, install source, debuggable flag, first-install/update time).
- **FR-APP-2** — Per-app quick actions: open App details, open/clear from Settings, view permissions screen. (Actual clearing/uninstalling is delegated to the OS via intents.)
- **FR-APP-3** — Full-package listing (`QUERY_ALL_PACKAGES`) gated to the off-Play flavor / explicit consent per **C6**.

### 6.8 Reporting, export, and share (FR-REP)
- **FR-REP-1** — Generate a **complete device report** aggregating every info section into a single document.
- **FR-REP-2** — Export formats: plain text, Markdown, and JSON at minimum; PDF as a stretch. Optional PII redaction toggle (mask identifiers, SSIDs, MACs) before sharing.
- **FR-REP-3** — Share via the Android share sheet, copy to clipboard, or save to a user-chosen file location.
- **FR-REP-4** — "Bug-report snippet" preset: a compact, ticket-ready block (device, OS, build, app under test, timestamp).

### 6.9 Home-screen widgets, Quick Settings tiles, app shortcuts (FR-SURF)
- **FR-SURF-1** — **Quick Settings tiles** (native TileService) for high-value actions: open Developer Options, toggle animations (T2), open Wi-Fi, open the DevAccess dashboard.
- **FR-SURF-2** — **Home-screen widgets** showing live stats (battery temp, RAM, CPU) refreshed on a sane cadence.
- **FR-SURF-3** — **App shortcuts** (launcher long-press) for the top favorited launchers/toggles.

### 6.10 Personalization & app settings (FR-SET)
- **FR-SET-1** — Material 3 theming: light/dark/system, dynamic color (Android 12+), accent selection.
- **FR-SET-2** — Configurable sampling intervals, units (°C/°F, MiB/MB), and which sections appear on the home dashboard.
- **FR-SET-3** — Backup/restore of favorites, layout, and preferences to a local file.
- **FR-SET-4** — Full accessibility support (TalkBack labels, scalable text, sufficient contrast) and localization readiness.

---

## 7. Permissions matrix

| Permission | Purpose | When requested | Failure behavior |
|-----------|---------|----------------|------------------|
| `INTERNET`, `ACCESS_NETWORK_STATE` | Network tools, connectivity info | At install | Network tools disabled |
| `ACCESS_WIFI_STATE` | Wi-Fi info | At install | Wi-Fi fields hidden |
| `ACCESS_FINE_LOCATION` / `COARSE` | SSID/BSSID, Wi-Fi scan (C5) | On entering Wi-Fi detail | Show "grant location for SSID" |
| `BLUETOOTH_CONNECT` (12+) | Bluetooth device info | On entering Bluetooth info | Section shows locked state |
| `READ_PHONE_STATE` | Some telephony fields | On entering Telephony | Restricted fields hidden |
| `SYSTEM_ALERT_WINDOW` | FPS/monitor overlay | On enabling overlay | Overlay feature disabled |
| `PACKAGE_USAGE_STATS` (special) | Usage-based insights (optional) | On enabling feature | Feature disabled |
| `QUERY_ALL_PACKAGES` | Full app list (C6) | Off-Play flavor only | Launchable-only listing |
| `WRITE_SETTINGS` (special) | T1 toggles (C3) | On requesting a T1 write | Stay read-only |
| `WRITE_SECURE_SETTINGS` | T2 toggles (C1) | Via adb wizard only | Stay read-only, show wizard |
| `FOREGROUND_SERVICE` (+ type) | Live monitors | On starting a monitor | Monitor won't start |
| `POST_NOTIFICATIONS` (13+) | Monitor/service notifications | On first service start | Silent service |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Reliable monitoring | On enabling persistent monitor | May be throttled |

- **FR-PERM-1** — All non-install permissions must be requested contextually with an in-app rationale immediately before the feature that needs them.
- **FR-PERM-2** — The app must remain fully usable for its read-only and launcher features with **zero** runtime permissions granted.

---

## 8. Non-functional requirements

- **NFR-PERF-1** — Cold start under ~2s on a mid-range device; the dashboard must render progressively (show cached/instant fields first, stream slow ones).
- **NFR-PERF-2** — Live monitors must not measurably drain battery at default sampling; sampling is throttled/paused when the relevant view isn't visible and when the screen is off.
- **NFR-PRIV-1** — No device data leaves the device by default. Sharing/export is always an explicit user action. No third-party analytics that transmit device identifiers in the default build.
- **NFR-PRIV-2** — Any identifier displayed must be labeled with its privacy sensitivity, and the redaction toggle must be available before any share.
- **NFR-SEC-1** — Elevated actions (T2/T3 writes) require an explicit confirmation and are logged locally so the user can review/undo them.
- **NFR-COMPAT-1** — Graceful behavior across OEM skins (Samsung One UI, Xiaomi HyperOS/MIUI, etc.) where intents or settings keys differ; unavailable intents fall back to the nearest parent screen and never crash.
- **NFR-COMPAT-2** — Correct handling of foldables/tablets (multi-display, resizable windows) and both light/dark system themes.
- **NFR-RELIABILITY-1** — Any platform-channel or system read that can fail must fail closed with a labeled "unavailable" state, never a crash.
- **NFR-A11Y-1** — Meets Android accessibility guidelines: content descriptions, focus order, dynamic type, and minimum touch targets.
- **NFR-I18N-1** — All user-facing strings externalized; layout tolerant of RTL and long translations.

---

## 9. Technical architecture (guidance, not prescription)

- **T-ARCH-1** — Flutter UI with a native Android layer (Kotlin) bridged via **type-safe platform channels (Pigeon)** for everything Dart plugins don't cover (secure-settings writes, sensor metadata, thermal API, per-core CPU, root/bootloader state, TileService, widgets).
- **T-ARCH-2** — Reuse mature plugins where they fit: `device_info_plus`, `battery_plus`, `connectivity_plus`, `network_info_plus`, `package_info_plus`, `sensors_plus`, `permission_handler`, `share_plus`, `android_intent_plus` (firing Settings intents), `home_widget` (widgets), `quick_actions` (shortcuts). Custom native code fills the gaps.
- **T-ARCH-3** — Clear separation: a **capability/tier service** that resolves what's possible at runtime, a **data layer** of typed device-info providers (each independently failable), and a **presentation layer** that renders locked/available states from capability results.
- **T-ARCH-4** — Foreground service(s) for live monitoring with the correct Android 14 service type declarations.
- **T-ARCH-5** — Native TileService and AppWidgetProvider implementations for **FR-SURF**, kept in sync with app state.

---

## 10. Out of scope / explicit limitations

- Toggling arbitrary developer options that Android exposes **only** through its own UI (no writable key, no adb path) — DevAccess deep-links to them but does not fake a toggle.
- Retrieving OS-restricted identifiers (IMEI/serial on API 29+) — surfaced as restricted.
- Reading full system logcat without an adb/privileged grant.
- Anything requiring a custom system signature or vendor privilege.

---

## 11. Future enhancements (backlog)

- Logcat viewer for users who grant `READ_LOGS` via adb.
- Wireless-debugging pairing helper with QR (Android 11+).
- Feature-flag inspector and per-app WebView implementation switcher.
- Scheduled/automated device-health snapshots.
- Comparison view across multiple saved device reports (device-lab use).
- Tasker/intent automation hooks.

---

## Appendix A — Settings deep-link launchers (target set)

Developer: Developer options, main Settings.
Connectivity: Wireless, Wi-Fi, mobile data/roaming, Bluetooth, NFC, VPN, hotspot/tethering, airplane mode.
Display: Display, brightness, screensaver/daydream, auto-rotate.
Sound: Sound, Do Not Disturb.
Apps: All apps, per-app details, default apps, notification listener access, usage access, overlay ("draw over other apps"), write-settings access, battery-optimization exemption.
Security & Privacy: Security, privacy, location, device info/about, encryption/credentials.
Storage: Internal storage, storage manager.
System: Date & time, language & input, keyboard, accessibility, backup, developer's "About phone → Build number" path for enabling dev options.

*(Availability of each intent varies by OEM/version per NFR-COMPAT-1; each launcher must fall back gracefully.)*

## Appendix B — Device information catalog (target fields)

**Device & Build:** manufacturer, brand, model, product, device, board, hardware, bootloader, fingerprint, build ID, build tags, build type, incremental, host, radio version, is-debuggable, is-emulator.

**OS & Security:** Android release + codename, API level, security patch date, kernel version & architecture, SELinux mode, verified-boot state, bootloader unlock state, encryption state, root/su/Magisk status, Play Integrity/attestation result, Google Play services version, uptime, boot time, developer-options-enabled flag, adb-enabled flag.

**Display:** resolution (px), density (dpi + bucket), physical size (in), refresh rate (and supported modes), HDR capabilities, cutout/insets, current brightness, current animation-scale values.

**SoC / CPU:** SoC/chipset name, architecture, supported ABIs (64/32-bit), core count, per-core min/max/current frequency, governor, cluster topology.

**GPU:** renderer, vendor, OpenGL ES version, Vulkan support/level.

**Memory:** total RAM, available RAM, low-memory threshold, is-low-RAM-device.

**Storage:** internal total/free, external/adopted total/free, per-volume list.

**Battery:** level %, status, health, plug type (AC/USB/wireless), technology, temperature, voltage, current-now, charge counter/capacity (mAh), cycle count (where exposed).

**Thermal:** system thermal status, available thermal-zone temperatures.

**Network:** connection type, is-connected, is-metered, IPv4/IPv6, gateway, DNS, subnet; Wi-Fi SSID/BSSID/RSSI/link-speed/frequency/band/channel/randomized-MAC (with location); throughput up/down.

**Telephony (where permitted):** network generation, carrier name, MCC/MNC, roaming state, signal strength, data state, SIM count.

**Sensors:** full enumeration with metadata + live values (per FR-SEN).

**Cameras:** enumerate cameras (front/back/external), resolutions, focal lengths, apertures, flash availability.

**System state:** locale, timezone, region, screen timeout, current DND/rotation state, battery-optimization status for DevAccess.

*(Any field unavailable on a given OS version is shown as "Restricted by OS" per FR-INFO-3.)*