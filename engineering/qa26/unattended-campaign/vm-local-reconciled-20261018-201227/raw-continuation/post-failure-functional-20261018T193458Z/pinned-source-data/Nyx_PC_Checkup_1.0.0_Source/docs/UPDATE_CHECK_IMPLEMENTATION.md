# Weekly Update Availability Check — Nyx PC Checkup 1.0.0

## Application identity

- Display name: `Nyx PC Checkup`
- Product ID: `nyx-pc-checkup`
- Installed/current version: `1.0.0`
- Manifest slug: `nyx-pc-checkup`
- Official endpoint: `https://www.dietrichailabs.com/updates/nyx-pc-checkup.json`

## Scope

This feature checks whether a newer approved public version is advertised by Dietrich AI Labs. It implements **notification plus opening the official release page only**. It is not an automatic updater.

Nyx does not download an executable, silently stage a package, execute server content, start an installer, add a service or scheduled task, replace itself, or poll continuously.

## Modules

- `updates/Versioning.psm1` — SemVer parsing and comparison, including prerelease identifiers.
- `updates/Manifest.psm1` — compiled product identity, endpoint, response bounds, schema validation, product validation, and URL allowlists.
- `updates/Preferences.psm1` — seven-day scheduling and UTC attempt persistence through the existing configuration system.
- `updates/UpdateChecker.psm1` — bounded HTTPS GET and `UP_TO_DATE`, `UPDATE_AVAILABLE`, `CHECK_FAILED`, `SKIPPED`, or `DISABLED` result production.
- `workers/UpdateCheckWorker.ps1` — short-lived non-elevated background process and bounded local result envelope.
- `ui/MainWindow.psm1` and `ui/Dialogs.psm1` — settings, manual command, restrained result UI, same-session suppression, and official-page opening.

## Automatic behavior

- **Automatically check for updates once a week** is enabled by default.
- On normal application startup, a short-lived worker runs only when no automatic attempt was recorded in the previous seven days.
- The UTC attempt timestamp is written before networking so offline, DNS, HTTP, malformed-response, and TLS failures cannot cause rapid retry loops in the same session or at every launch.
- Automatic up-to-date and failure results are silent.
- Update failure never prevents application startup or normal offline use.
- No permanently running process is created.

Existing configuration keys:

```text
updates.enabled
updates.lastCheckUtc
```

## Manual behavior

**Settings → Check for Updates Now** bypasses the seven-day timer, including when automatic checking is disabled.

Results:

- Installed version equal to or newer than the manifest: **Nyx PC Checkup is up to date.**
- Newer manifest version: **Update Available**, with **View Update** and **Remind Me Later**.
- Failure: **Unable to check for updates right now. Please try again later.**

A version already shown in the current application session is not repeatedly prompted. **Remind Me Later** dismisses only that prompt and does not disable future checks.

## Network and privacy boundary

The request is a normal HTTPS GET for public JSON metadata. It intentionally includes no username, Windows account, machine name, hardware serial, persistent device ID, document name/content, local path, email address, usage history, installed-app inventory, scan result, or telemetry.

The minimal User-Agent is `NyxPCCheckup/1.0.0`. Normal network metadata inherent to HTTPS and the user’s network path may still be processed by the website or hosting infrastructure.

## Security validation

- HTTPS only; platform TLS/certificate validation is not replaced or suppressed.
- Redirects are disabled.
- Timeout: 5 seconds.
- Maximum response: 65,536 UTF-8 bytes.
- Expected content type: `application/json`.
- Root must be a JSON object.
- Schema version must be `1`.
- `product` must exactly equal `nyx-pc-checkup`.
- Required fields must be present.
- Version must be valid supported SemVer.
- Display fields are length-bounded and reject control characters.
- Optional SHA-256 must be empty or exactly 64 hexadecimal characters.
- Manifest endpoint is exact and compiled.
- Release and download actions allow only HTTPS on `www.dietrichailabs.com`, default port, no credentials/query/fragment, and approved paths.
- Unknown future manifest fields are ignored.
- Older manifest versions are never offered as downgrades.

The optional test transport scriptblock in `Invoke-NyxUpdateCheck` is used only by the shipped Windows QA harness. Production UI and worker code never pass it, and injected data remains subject to size, JSON, schema, product, version, and URL validation.

## Tests

Engineering source/reference tests cover:

- first automatic check;
- suppression inside seven days;
- due at seven days;
- manual bypass;
- disabled automatic checks;
- SemVer equality, patch/minor/major, multi-digit components, beta/RC, downgrade, and malformed values;
- correct/wrong product, unsupported schema, missing field, invalid JSON, oversized response, and invalid URLs;
- notification-only architecture and unchanged TLS validation;
- nonblocking UI worker, manual result handling, and same-session suppression.

The Windows smoke suite additionally injects deterministic timeout, DNS, TLS, HTTP 404/500, malformed JSON, oversized, wrong-product, newer, equal, and older responses, and performs a real bounded manual request to the compiled endpoint. These Windows cases have not been executed on the Linux Engineering host.

## Website publication boundary

No Dietrich AI Labs website project was supplied or modified in this task. This handoff does not publish `/updates/nyx-pc-checkup.json` and does not announce QA7 as a public release.

Manifest publication is outside this Engineering-to-QA handoff. It must occur only after a separately authorized public-release process uploads and verifies the exact approved bytes; the manifest remains the final public update flag. Recommended cache behavior for `/updates/*.json` is equivalent to:

```text
Cache-Control: public, max-age=300, must-revalidate
```
