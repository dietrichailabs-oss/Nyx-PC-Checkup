# Architecture — Nyx PC Checkup 1.0.0

## Purpose

Nyx PC Checkup is a local-first Windows health utility for normal users. The architecture separates observation, deterministic interpretation, presentation, reversible actions, destructive actions, update-notification metadata, report export, and packaging. A failure in one check must not silently modify the computer or terminate unrelated checks.

## Runtime shape

The installed runtime consists of:

- a small native Windows x64 launcher with an embedded `asInvoker` manifest; the launcher starts PowerShell in explicit STA with `CREATE_NO_WINDOW` for console suppression but does not apply a hidden startup state to the WinForms child;
- a modular Windows PowerShell 5.1 application;
- a WinForms user interface;
- short-lived worker processes for scans, confirmed local actions, and update checks.

There is no service, driver, scheduled task, resident tray process, remote account, analytics client, continuous poller, or automatic updater.

## Layer boundaries

1. **Native shell** — locates the installed application, starts Windows PowerShell without elevation, and returns its exit code. It contains no health or update logic.
2. **Application shell** — owns single-instance behavior, DPI setup, navigation, global UI state, background-worker coordination, version identity, and the top-level error boundary.
3. **Core** — owns local paths, bounded configuration recovery, structured result models, privacy minimization, rotating diagnostics, scan persistence, and current-user action history.
4. **Health rules** — centralizes deterministic thresholds and status aggregation. UI files do not own health thresholds.
5. **Checks** — read local operating-system and file metadata and return structured results. A failed check becomes **Unknown** rather than cancelling unrelated checks.
6. **Actions** — are separate from checks. Scanning never calls action modules. Every change requires explicit user confirmation and current-state revalidation.
7. **Updates** — fetches and validates one public JSON manifest and returns a small result state. It does not own UI, downloads, installer execution, or release publication.
8. **Reports** — recursively minimizes structured values before TXT, JSON, or PDF serialization and requires preview before export.
9. **Platform boundary** — Windows registry, Windows Security, Windows Update, Startup folders, Recycle Bin, and installer behavior remain under Windows-specific modules. Core result/rule contracts remain portable for a later Linux/Nyx OS adapter.

## Runtime composition

`core/RuntimeComposition.psm1` is the sole owner of application-module loading. Runtime modules never import or force-reload one another. The composition root maintains an ordered inventory of exact relative paths and expected exports, rejects same-name modules from another path, imports ordinary files into global scope without `-Force`, and verifies the cumulative command surface after every dependency layer.

Application and worker entry points request bounded profiles (`Diagnostics`, `Update`, `Uninstall`, `Actions`, `Scan`, or `UI`). A module loaded from the expected path but missing an expected export causes a deterministic failure rather than an implicit reload. This design prevents Windows PowerShell 5.1 nested-import session-state loss and makes the complete graph independently testable.

## Scan flow

`Nyx PC Checkup.exe` → `app/NyxPCCheckup.ps1` → `ui/MainWindow.psm1` → `workers/ScanWorker.ps1`.

The scan worker:

- accepts only UUID-named output, progress, and cancel files inside Nyx-owned local temporary storage;
- imports read-oriented check modules;
- emits JSON Lines progress;
- checks cancellation between modules and inside bounded long scans;
- isolates each check failure;
- preserves partial results;
- writes a read-only result envelope atomically;
- persists only the latest bounded scan result.

Quick Check covers system overview, system-drive space, Windows Update indicators, security indicators, startup entries, backup indicators, uptime, and network basics. Full Check adds folder-size analysis, large-file and Downloads analysis, bounded duplicate candidates, cleanup preview, battery, drive health, performance snapshot, and installed applications.

## Action IPC flow

The UI shows an exact confirmation, writes a UUID-bound request under the Nyx temporary directory, hashes the exact request bytes, and passes that SHA-256 to `ActionWorker.ps1`. The worker validates:

- the request/result filename pattern;
- exact Nyx temporary-directory ownership;
- ordinary-file and non-reparse status;
- request size;
- request hash before parsing;
- the explicit confirmation marker;
- the fixed operation allowlist.

The action worker is always non-elevated. Supported operations are current-user startup disable, current-user startup restore, and selected cleanup.

## Current-user startup rollback

Version 1 writes only to:

- `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run`;
- `HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce`;
- the current user’s Startup folder.

Disable sequence:

1. Re-enumerate and validate the selected source.
2. Reject all-users entries as read-only without launching UAC.
3. Verify the current command, value kind, ordinary-file state, length, and hash where applicable.
4. Create a new UUID action folder under Nyx local data.
5. write a DPAPI CurrentUser-protected journal atomically before mutation;
6. perform only the selected current-user registry removal or Startup-file move;
7. append privacy-minimized action history.

Restore sequence:

1. Enumerate every rollback folder independently.
2. Reject unexpected names, reparse points, oversized journals, decryption failure, wrong user SID, wrong scope, unsupported paths, and malformed state.
3. Refuse to overwrite a conflicting registry value or file.
4. restore the exact prior value kind/command or exact backed-up file;
5. close the active journal only after successful restoration.

If Windows state changed but a later step fails, the journal remains available. If mutation never occurred, the unused write-ahead journal is removed.

## Exact QA2 current-user rollback compatibility

QA2 current-user journals are a separate compatibility case from legacy machine state. A QA2 user journal was protected with DPAPI CurrentUser but omitted `JournalVersion` and used an empty `OwnerSid`. QA7 considers compatibility only after successful DPAPI CurrentUser decryption from an ordinary bounded journal in the exact current-user rollback folder.

The compatibility converter accepts only the exact QA2 user property set, `JournalScope='User'`, actual Boolean `RequiresElevation=$false`, exact empty legacy owner field, matching ActionId, and the current-user registry/Startup source boundaries. Backup path, directory layout, ordinary-file/reparse status, length, and SHA-256 are validated. Valid state is normalized in memory to current schema and revalidated before it is exposed to restore code. Restore revalidates again immediately before mutation.

Machine pointers, extra/missing properties, malformed types, wrong paths, changed payloads, failed DPAPI decryption, and ambiguous state remain preserved and make inventory incomplete. The compatibility path never authorizes an all-users write and never silently rewrites a legacy journal during inventory.

## All-users startup entries and legacy QA2 state

`HKLM` Run/RunOnce and Common Startup entries are enumerated for visibility only. They are marked `CanModify=false`, and the UI does not enable a change control for them. Runtime source contains no `RunAs` path.

The failed QA2 candidate could create machine-level rollback journals under:

`%ProgramData%\DietrichAI.NyxPCCheckup\startup-rollback`

QA7 never creates or uses those journals to authorize a write. The uninstaller independently enumerates that root without relying on a user pointer. A present, malformed, unexpected, reparse-backed, oversized, or inaccessible legacy obligation returns `Present` or `Unknown` and blocks uninstall with exit code 7 before code, shortcuts, registration, or recovery data are removed. Separate controlled repair is required.

## Cleanup flow

Cleanup uses scan → categorize → preview → select → confirm → revalidate → Recycle Bin → exact result.

The action module:

1. re-enumerates only approved cleanup roots;
2. matches only user-selected stable candidate IDs;
3. revalidates parent chains, ordinary-file status, reparse status, size, age, and supported category;
4. sends supported files to the Windows Recycle Bin one at a time;
5. reports exact successes, failures, and bytes moved.

No scan deletes files. Personal folders are never bulk-deleted, and Windows component stores, browser profiles, restore points, application databases, and cloud-synchronization state are excluded.

## Update-notification flow

On startup the UI reads the existing configuration object. If automatic checks are enabled and no attempt occurred during the previous seven days, it starts `UpdateCheckWorker.ps1` as a short-lived, non-elevated background process. Manual checks bypass the timer.

The worker calls `UpdateChecker.psm1`, which:

- records the UTC attempt timestamp before networking, preventing retry loops after failure;
- fetches only `https://www.dietrichailabs.com/updates/nyx-pc-checkup.json`;
- uses normal Windows TLS validation;
- disables redirects;
- uses a five-second timeout and 64 KiB maximum body;
- requires JSON content type and strict UTF-8;
- validates schema version 1, exact product ID, required fields, semantic version, timestamp, SHA-256 shape, display-text bounds, and URL allowlist;
- returns `UP_TO_DATE`, `UPDATE_AVAILABLE`, `CHECK_FAILED`, `SKIPPED`, or `DISABLED`.

Automatic success and failure are normally silent. A newer version may prompt once per application session. Manual up-to-date and failure results are shown. **View Update** opens only the validated Dietrich AI Labs release page in the default browser. No executable is downloaded or launched.

## Privacy-minimization flow

`Protect-NyxObject` recursively traverses dictionaries, arrays, and object properties before serialization. Secret-bearing role names are replaced with `[REDACTED]`. Text minimization then redacts profile paths, usernames, valid IPv4 and IPv6 tokens through `IPAddress.TryParse`, bearer values, assignment-style secrets, and email addresses unless the user explicitly enables the supported report identity options.

Report, action-history, and log consumers call privacy minimization before persistence or export. Depth and file-size bounds prevent unbounded traversal.

## Local data layout

Per-user data lives beneath:

`%LOCALAPPDATA%\Dietrich AI Labs\Nyx PC Checkup`

It may contain:

- `config.json`;
- bounded rotating logs;
- the last scan;
- privacy-minimized action history;
- DPAPI CurrentUser startup rollback journals and backed-up Startup-folder files;
- generated reports chosen by the user;
- bounded temporary worker IPC.

Normal uninstall preserves local data unless purge is explicitly selected. Uninstall does not purge recovery data if rollback validation or restoration fails.

## Packaging architecture

The builder creates native x64 launcher, uninstaller, and setup PEs from local source and local LLVM tools. It stages only an allowlisted runtime payload, writes an exact payload manifest, builds deterministic portable/source ZIPs, embeds the payload into setup, runs structural/contract/package tests, creates evidence, and assembles one master handoff ZIP.

The installer uses a fixed per-user destination, create-new extraction semantics, reparse/collision checks, exact payload hashes, transactional shortcut/registry finalization, and an app-running mutex gate. It installs no service, task, driver, firewall rule, or background updater.
