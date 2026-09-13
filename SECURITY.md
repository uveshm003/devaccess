# Security policy

## Supported versions

DevAccess is developed on `main`. Security fixes land there and ship in the next release;
older releases are not patched separately.

| Version | Supported |
|---------|-----------|
| 1.0.x   | ✅ |
| < 1.0   | ❌ |

## Reporting a vulnerability

**Please do not open a public issue for a security problem.**

Report it privately, either way:

- GitHub → the repository's **Security** tab → *Report a vulnerability* (private advisory), or
- email **uveshmenpur.03@gmail.com** with `DevAccess security` in the subject.

Please include:

- what the issue is and what an attacker gains,
- the affected version, flavour (`play` / `foss`), device and Android version,
- the access tier involved (T0 base / T1 `WRITE_SETTINGS` / T2 `WRITE_SECURE_SETTINGS` / T3 root),
- steps to reproduce, and a proof of concept if you have one.

You should get an acknowledgement within 7 days and an assessment within 14. If a fix is
warranted, it will be developed privately and released with credit to you unless you would
rather stay anonymous. Please give a reasonable window before disclosing publicly.

## Scope

DevAccess ships no backend, makes no network calls except diagnostics the user explicitly
starts, and collects nothing. The interesting surface is local:

**In scope**

- An elevated (T2/T3) write that happens without confirmation, without verification, or
  without an audit-log entry.
- A path that escalates beyond the tier the app has actually resolved.
- Leaking identifier fields (IMEI-class values, SSID/BSSID, serials) past the redaction
  toggle in a report, export or share.
- Exported components — the tiles, widget, shortcuts, activities and services — doing
  something privileged on behalf of another app's intent.
- A device-local file or preference written somewhere world-readable.
- Command injection through the diagnostic tools or the root shell.

**Not in scope**

- Android behaving as documented: `WRITE_SECURE_SETTINGS` being grantable over adb, `su`
  granting root on an already-rooted device, values the OS restricts to privileged apps.
  These are the platform's model, and the README documents them.
- Anything that requires the attacker to already have physical access with USB debugging
  enabled and authorised, or an already-rooted device with a granted `su`.
- Missing hardening that has no demonstrated impact.
