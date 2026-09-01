# Independent QA Test Plan — Nyx PC Checkup 1.0.0 QA13

## Authority and evidence

QA tests the exact immutable QA14 handoff and assumes Engineering missed something. QA never silently edits Engineering source. Record Eastern start/stop timestamps, elapsed time, environment, exact artifact names/sizes/SHA-256, findings/severity/evidence, and final `PASS`, `CONDITIONAL PASS`, `HOLD`, or `FAIL`.

## Prior QA9 baseline — mandatory regression boundary

QA9 already recorded these native results before final visual acceptance failed:

- Smoke: **97/97 PASS**
- Standard privilege/rollback: **12/12 PASS**
- Exact QA2 migration: **244/244 PASS**
- Standard installer lifecycle: **44/44 PASS**
- Elevated privilege/rollback: **14/14 PASS**
- Elevated installer lifecycle: **50/50 PASS**

QA14 changes native launcher and UI-state bytes, so QA must verify no regression to those product behaviors. Previously passed evidence may guide prioritization but does not authorize ignoring a behavior affected by new bytes.

## QA10 failure being corrected

Independent QA10 reproduced `QA10-F-009` on native Windows PowerShell 5.1: closing the real UI could surface an unhandled .NET dialog and a Nyx terminal error because four optional UI temp-path fields were initialized to empty strings and passed directly to `Remove-Item -LiteralPath`. QA14 must carry forward the QA9-F-008 responsive UI correction while closing F-009.

## Preferred manifest-bound phase runner

After extracting the master handoff, use root `RUN_QA15_WINDOWS_GATE.ps1` with inbox `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`, not PowerShell 7. The runner verifies identities before execution and emits phase evidence. Each phase must include `QA15_WINDOWS_PARSE_PREFLIGHT.json` and `QA15_WINDOWS_RUN_SUMMARY.json`. Expected `HarnessRevision` is `QA15-F012-PS51-15`.

Run Smoke, Standard, and Elevated on appropriate disposable Windows 10/11 x64 snapshots. A process exit code is insufficient by itself: expected JSON reports must exist, parse, contain internally valid totals, and report PASS.


# QA12-F-011 installed-launch acceptance — RELEASE BLOCKER

QA12 reproduced a live invisible singleton from the supported installed desktop shortcut on a normal Hyper-V VM. QA14 must be tested from an interactive non-elevated desktop and must not substitute direct-source acceptance probes for the installed entry point.

Required assertions:

1. verify exact Setup, installed launcher, and installed script identities;
2. verify shortcut target and working directory;
3. begin from zero prior Nyx launcher/application/worker processes;
4. launch the actual desktop shortcut;
5. observe exactly one visible, usable `Nyx PC Checkup` main window within a bounded timeout;
6. verify the main window is taskbar-eligible and capture it;
7. launch a second installed instance and observe visible singleton behavior while the first window stays usable;
8. close the first window and prove child and launcher exit with no unnecessary Nyx process;
9. launch the installed EXE directly and prove the same visible behavior;
10. repeat isolated script controls without explicit STA and with explicit STA, each from clean state; and
11. immediately relaunch after close and prove a new visible usable window.

A live child that owns the singleton without a visible main window is an immediate FAIL. Console suppression must not suppress the WinForms UI. Singleton protection must remain enabled.

## Carried-forward migration harness corrections

The QA14 source incorporates QA9-WH-004, WH-005, and WH-006 rather than reverting to the older QA9 Source ZIP harness state. The migration suite must retain:

- exact immutable QA2 Paths and ActionHistory hash pinning;
- exact QA2 CurrentUser DPAPI protect/unprotect use;
- exact 17-property QA2 legacy journal schema;
- harness-owned QA2 data-layout derivation without calling the historical broken QA2 startup enumerator/disable path;
- reset-run evidence, exact bounded cleanup, reparse protections, and clean-state assertions before each QA2 reinstall; and
- all five exact migration scenarios, Machine-pointer rejection, and QA14 uninstall consuming/restoring migrated QA2 current-user rollback.

## Intake and packaging

- Verify outer ZIP CRC, traversal/path safety, duplicate/case-collision/symlink absence, root layout, `MASTER_MANIFEST.json`, and `SHA256SUMS.txt`.
- Verify Setup, Portable, Source, exact QA2 fixtures, and source-tree identity.
- Verify Portable payload against `PAYLOAD_MANIFEST.json`.
- Confirm native x64 Windows GUI PE files, embedded `asInvoker` manifests, unsigned QA-candidate status, and expected imports.
- Confirm runtime excludes source, tests, QA evidence, caches, logs, credentials, user data, and superseded builds.

## Historical regression matrix

Re-run or substantively exercise historical F-001 through F-009 boundaries: no unwanted elevation or all-users startup mutation; fail-closed rollback discovery; report minimization/redaction; exact QA2 DPAPI rollback migration; Windows PowerShell 5.1 parser/list/module composition; safe uninstall cleanup/purgedata; zero-item cleanup/download aggregation; and QA9-F-008 responsive UI/accessibility.

## Functional and safety matrix

- Fresh standard-user install/launch, single instance, and no unnecessary resident process after close.
- Quick and Full Check responsiveness, progress, **Cancel scan**, partial results, module failure isolation, and read-only scan behavior.
- Storage/download bounds, Unicode/long paths, locked/disappearing files, access denial, reparse points, network/removable/offline locations, and very large trees.
- Windows Update/security/backup/battery/drive/performance/network/installed-app/uptime states, including conservative Unknown handling.
- Cleanup default-unselected, exact bytes/consequence, confirmation, revalidation, mutation/path/reparse races, partial failure, and Recycle Bin behavior.
- Startup stale IDs, unsupported/all-users read-only wording, reversible current-user actions, write-ahead rollback, conflicts, wrong user, tampering, and journal preservation.
- Report preview and **Export report**, redaction, TXT/JSON/PDF where provided, logging rotation/cap/delete, and no upload.

## Weekly update checker

- First automatic check; suppression inside seven days; check at/after seven days; disabled setting; manual bypass; no retry loop.
- Equal/newer/older/multi-digit/beta/RC/malformed versions.
- Correct/wrong product, unsupported schema, missing fields, unknown fields, invalid root, oversized response, and invalid URLs.
- Timeout, DNS, TLS, 404/500, redirect, invalid UTF-8, empty body, and unexpected content type.
- Manual up-to-date/failure; update prompt; one prompt per version/session; Remind Me Later behavior.
- No executable download, install/execute path, service/task, telemetry, inventory upload, TLS bypass, or arbitrary-domain open.

# QA10-F-009 UI close lifecycle acceptance — RELEASE BLOCKER

QA10 failed Standard before the final UI matrix because a normal `FormClosing` callback passed empty optional path strings to `Remove-Item -LiteralPath`. QA14 must prove both the shipped fix and the exact cleanup boundary.

Required native Windows PowerShell 5.1 / WinForms close cases:

1. launch and **close immediately** before scan or update activity;
2. launch with **automatic update disabled**, then close;
3. launch with updates enabled and close **before update output exists**;
4. complete a real **Quick Check**, then close;
5. start a scan, **Cancel scan**, then close;
6. perform an **update-check** success or failure path, then close;
7. **close/relaunch** twice under the same Windows user;
8. no **unhandled .NET** exception dialog;
9. no Nyx **terminal error** dialog;
10. application process exits cleanly;
11. no unnecessary residual Nyx UI/**background process** remains; and
12. temp cleanup never deletes a file **outside the exact Nyx temp root**.

The Smoke harness includes manifest-bound QA13 acceptance probes for immediate close with automatic update disabled and enabled/due, plus direct empty-path/outside-root cleanup assertions. Those automated cases do not replace QA's native start/cancel/update/manual close observations.

Any empty/null/whitespace cleanup parameter-binding exception, cleanup outside the exact Nyx temp root, stuck process, or terminal close error is a release blocker.

# QA9-F-008 final UI / accessibility acceptance — RELEASE BLOCKER

This matrix is mandatory. QA9 failed at 150% scaling on a 1366×768-class viewport, so visual inspection—not static source review—is required.

### Theme × scale matrix

Test **Follow Windows**, **Dark**, and **Light** themes at each of:

- **100%**
- **125%**
- **150%**
- **200%**

At minimum include a **1366×768** constrained working-area case for every scale where Windows permits it, and reproduce the exact prior-failure class at **150% / 1366×768**.

### Pages

Inspect every page at each required matrix point:

1. Home
2. Checkup
3. Storage
4. Startup
5. Security
6. Updates
7. Backup
8. System
9. Cleanup
10. Apps / Installed Applications
11. Settings

### Visual/layout acceptance

For every page:

- no clipped or overlapping required labels, buttons, status text, cards, navigation, grid headers, or global controls;
- meaningful text wraps or scrolls instead of disappearing behind ellipsis;
- **Export report** remains visually reachable;
- scan progress and **Cancel scan** remain visually reachable while a scan is active;
- version/footer information remains reachable without covering actions;
- Startup `Disable selected`, `Re-enable selected`, and `Open file location` are discoverable without guessing that hidden controls exist;
- Apps `Run Full Check` and `Open selected folder` are discoverable;
- Settings `Check for Updates Now`, weekly-update preference, `Open local data folder`, `Delete local logs`, and `Save settings` are readable/reachable;
- Cleanup selection/action controls are readable, default unselected, and reachable;
- grids remain readable using horizontal scrolling and/or cell tooltips where content exceeds width; and
- resizing the window smaller/larger does not strand mandatory controls.

### Keyboard and focus acceptance

Using only keyboard navigation:

- traverse forward with **Tab** and backward with **Shift+Tab**;
- visible focus indication is always present;
- focusing an offscreen control causes its scrollable page/container to bring it into view;
- activate each primary page action with keyboard where enabled;
- no focus trap occurs in navigation, grid, settings, or cleanup controls; and
- focus order remains understandable for a nontechnical user.

### Accessibility/content acceptance

- Good / Needs Attention / Optional / Unknown remain distinguishable without color alone.
- Status icons/text and primary actions are legible in Dark, Light, and Follow Windows.
- Language remains plain, non-alarmist, and free of fake health scores or fake urgency.
- Unknown remains honest when data is unavailable.
- Startup all-users entries remain visibly read-only where applicable.
- Application close terminates normal processes and leaves no unnecessary always-running background component.

Any required control clipped, unreachable, visually hidden, or keyboard-inaccessible at a required matrix point is a release blocker.

## Installer lifecycle

- Fresh install with/without desktop shortcut; app-running conflict; same-version repair; exact QA2 upgrade.
- Interrupted staging/activation/finalization and rollback.
- Quiet install/uninstall, preserved local data, explicit `/purgedata`, active rollback conflict/retry, legacy machine rollback exit `7`.
- Clean uninstall/reinstall; no services, scheduled tasks, drivers, firewall/network changes, or updater leftovers.

## Verdict gate

PASS requires the exact immutable **QA13** bytes to satisfy functional, migration/recovery, safety, privacy, privilege, weekly-update, **complete UI/accessibility matrix**, packaging, and lifecycle gates with no release blocker. Any shipped-byte correction creates a new immutable candidate and invalidates this verdict.
