# Contributing to DevAccess

Thanks for taking the time. DevAccess is a Flutter + Kotlin Android app with **no
third-party dependencies** — that constraint (G6 in `requirement.md`) shapes most of what
follows.

## Getting set up

```bash
git clone https://github.com/uveshmenpur/devaccess.git
cd devaccess
flutter pub get
flutter test
flutter analyze
flutter run --flavor foss        # or --flavor play
```

Requirements: Flutter with Dart SDK `^3.12.2` (developed on Flutter 3.44), JDK 17, Android
SDK with API 36, min SDK 24. Most of the app is only meaningful on a real device or
emulator — the platform channels are the whole point.

Handy while developing:

```bash
# Exercise elevated (T2) paths without root
adb shell pm grant com.devaccess.app.foss android.permission.WRITE_SECURE_SETTINGS

# Render real screens to PNG without a device
PREVIEW_OUT=build/preview flutter test test/preview_capture.dart --plain-name "home dark"
```

## Ground rules

1. **No new dependencies.** `pubspec.yaml` declares `flutter` and `flutter_lints`, and
   nothing else; `android/app/build.gradle.kts` pulls in no libraries. A PR that adds one
   needs to argue in the description why the capability cannot be written by hand, and it
   will usually be declined. Draw the graph, write the painter, bridge the API.
2. **No backend, no analytics, no network calls the user did not ask for.** The only
   traffic DevAccess makes is a diagnostic the user explicitly started (ping, traceroute,
   DNS, HTTP latency).
3. **Surface platform limits, never fake them.** If Android refuses a value, report
   *Restricted by OS* with the reason and, where one exists, a deep link to the Settings
   screen that can do it. Zeros, blanks and silent failures are bugs.
4. **Every elevated write is confirmed, verified and audited.** T2/T3 writes ask first,
   re-read the key afterwards to confirm, and append to the local audit log with undo.
5. **Respect the tier model.** Anything the current tier cannot do renders a locked badge
   with an explanation — it is never hidden and never throws.
6. **Use the design tokens.** Spacing, radii and motion come from
   `lib/core/theme/app_tokens.dart`; status colours come from `AppPalette`, not from
   hard-coded greens and reds. New shared chrome belongs in `lib/widgets/`.
7. **Keep native handlers failure-tolerant.** Every method-channel handler returns a
   structured error instead of throwing (NFR-RELIABILITY-1), and slow work runs on a
   background executor so the platform thread never blocks.
8. **Play vs FOSS.** `play` and `foss` differ only where Play policy forces them to.
   `QUERY_ALL_PACKAGES` stays in `android/app/src/foss/AndroidManifest.xml`; gate anything
   else on `BuildConfig.FULL_ACCESS`.

## Making a change

- Branch from `main`.
- Match the surrounding code — the repo has a consistent voice in both Dart and Kotlin.
- Add or update tests in `test/` for anything with logic worth pinning (catalogues,
  models, report building). Device-dependent code is exercised through the canned bridge.
- Run `flutter analyze` and `flutter test` before pushing; CI runs both and will fail the
  PR on either.
- `dart format` on files you touch is welcome. CI reports formatting but does not block on
  it, because the tree predates the current formatter — once someone lands a one-time
  `dart format lib test` pass, the gate in `.github/workflows/ci.yml` can drop its
  `continue-on-error`.
- If your change touches a requirement ID, update the traceability table in `README.md`.
- Write a commit message that says what changed and why. One logical change per commit.

## Pull requests

Open an issue first for anything large — a new screen, a new native subsystem, a change to
the tier model. Small fixes can go straight to a PR.

In the PR description, say what you changed, how you tested it (which device, which Android
version, which tier), and which requirement IDs it touches. Screenshots or a screen
recording help a lot for UI work.

By contributing you agree that your contributions are licensed under the
[Apache License 2.0](LICENSE), and that you have the right to submit them.

## Reporting things

- **Bugs and feature requests**: use the issue templates.
- **Security vulnerabilities**: do not open a public issue — see [SECURITY.md](SECURITY.md).

## Code of conduct

Participation is governed by the [Contributor Covenant](CODE_OF_CONDUCT.md).
