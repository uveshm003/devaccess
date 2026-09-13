## What this changes

<!-- One or two sentences. Link the issue: Fixes #123 -->

## Why

<!-- The problem it solves. For UI work, a screenshot or screen recording. -->

## How it was tested

- Device / Android version:
- Flavour: `play` / `foss`
- Access tier exercised: T0 / T1 / T2 / T3
- <!-- What you actually did to verify it -->

## Requirement IDs touched

<!-- e.g. FR-TG-4, NFR-SEC-1 — and update the traceability table in README.md -->

## Checklist

- [ ] `flutter analyze` is clean
- [ ] `flutter test` passes
- [ ] No new Dart or Gradle dependency
- [ ] No backend call, no analytics, nothing leaves the device unprompted
- [ ] Platform limits are surfaced with a reason rather than faked or silently swallowed
- [ ] Any elevated (T2/T3) write is confirmed, verified by re-read, and audited
- [ ] Spacing/radius/motion come from `app_tokens.dart`; status colours from `AppPalette`
- [ ] Docs updated (`README.md` / `CHANGELOG.md`) where behaviour changed
