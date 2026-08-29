# QA2 Failure Correction Matrix — Nyx PC Checkup 1.0.0

## Prior failed identity

Independent QA reviewed and failed:

- Engineering build: `2026.08.23-eng-qa2`
- Engineering handoff SHA-256: `61B870429BDB22A3F7106A8720A9EE9845D9C2D8B499336E5E1EF9EFBC4D81AF`
- Independent QA failure handoff: `Nyx_PC_Checkup_1.0.0_Independent_QA_FAIL_Master_Handoff(1).zip`
- Independent QA failure handoff size: `667,197 bytes`
- Independent QA failure handoff SHA-256: `5DE23C322DD48C69FCEC47331217962603CDE8011CDE9A90083371D3FDDFF6E5`
- QA verdict: **FAIL — RELEASE BLOCKED**
- QA findings: `F-001`, `F-002`, and `F-003`

This document records the original QA2 correction design, first carried by QA3/QA4 and preserved in current build `2026.08.29-eng-qa11-f010-r2`. It does not close QA’s verdict by itself. Independent QA must execute the supplied Windows suites and retest the exact immutable QA11 candidate.

## F-001 — CRITICAL — Elevated code from a user-writable install tree

### QA finding

QA2 supported all-users startup changes by launching PowerShell workers and modules from `%LOCALAPPDATA%` with `-Verb RunAs`. The request hash authenticated the request but not the elevated code bytes. The uninstaller used the same unsafe trust pattern.

### Correction introduced in QA3 and preserved through QA7

- Removed all runtime `RunAs`, elevation detection, privileged action, and elevated-uninstall paths.
- Version 1 now modifies only current-user startup entries:
  - `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
  - `HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce`
  - the current user’s Startup folder
- All-users `HKLM` and Common Startup entries remain visible but **all-users entries are read-only**.
- The action worker accepts only fixed non-elevated operations and UUID-bound local IPC files.
- Native launcher, setup, and uninstaller remain `asInvoker` and contain no elevation verb.

### Engineering evidence

- `src/app/actions/StartupActions.psm1`
- `src/app/checks/StartupApps.psm1`
- `src/app/workers/ActionWorker.ps1`
- `src/app/workers/UninstallWorker.ps1`
- `src/app/ui/MainWindow.psm1`
- `native/app.manifest`
- Python contracts proving no runtime/native elevation request
- `tests/powershell/Run-WindowsElevatedStartupRollback.ps1`

### Required independent regression

- Standard user and split-token administrator
- Alternate-administrator observation
- Select an all-users entry and verify no UAC prompt and no machine-state change
- Worker/module replacement attempt
- Request replacement attempt
- Reparse/junction substitution
- Uninstall with a legacy machine-level rollback obligation

## F-002 — HIGH — Legacy machine rollback could become undiscoverable

### QA finding

QA2 began recovery discovery from a per-user DPAPI pointer. Deleting or corrupting the pointer could hide an authoritative ProgramData machine journal and permit uninstall to miss a restoration obligation.

### Correction introduced in QA3 and preserved through QA7

QA7 creates no new machine-level startup rollback state because all-users changes are no longer supported. The uninstaller nevertheless protects users upgrading from or testing QA2:

- It independently derives `%ProgramData%\DietrichAI.NyxPCCheckup\startup-rollback`.
- Discovery does not depend on the current-user DPAPI inventory or pointer.
- Only an actual `ObjectNotFound` result is treated as clear.
- Permission denial, malformed roots, reparse points, unexpected files/folders, invalid action IDs, oversized journals, invalid JSON, and invalid machine scope become `Unknown`.
- A readable active legacy journal becomes `Present`.
- `Present` or `Unknown` causes uninstall exit `7` before application files, shortcuts, uninstall registration, or local recovery data are removed.
- Current-user rollback storage is separately and exhaustively inventoried; malformed or inaccessible state causes exit `6` before removal.

QA7 deliberately does not execute or restore legacy machine state from LocalAppData. That would recreate the F-001 trust problem. A legacy machine obligation requires independent repair before uninstall can continue.

### Engineering evidence

- `Get-NyxLegacyMachineRollbackObligations` in `src/app/actions/StartupActions.psm1`
- `Get-NyxStartupRollbackInventory` in `src/app/core/ActionHistory.psm1`
- ordering and exit boundaries in `src/app/workers/UninstallWorker.ps1`
- `tests/powershell/Run-WindowsElevatedStartupRollback.ps1`
- `tests/powershell/Run-WindowsInstallerLifecycle.ps1`

### Required independent regression

- Machine journal present with no per-user pointer
- Corrupt or missing pointer directory
- Malformed, reparse-backed, oversized, and inaccessible legacy storage
- Empty legacy root
- Current-user rollback conflict
- Verify exits `7` and `6` occur before payload/data/shortcut/registration removal

## F-003 — MEDIUM — Privacy redaction missed compressed IPv6 and structured secrets

### QA finding

QA2 serialized objects before regex redaction. It missed `::1`, `2001:db8::1`, IPv4-mapped IPv6, quoted/multiword values, and JSON properties such as `Password`, `token`, and `Authorization`.

### Correction introduced in QA3 and preserved through QA7

- Reports recursively minimize structured values before TXT, JSON, or PDF serialization.
- Secret-bearing property names are normalized and replaced with `[REDACTED]` at any supported nesting depth.
- Covered roles include passwords, tokens, authorization values, cookies, API/access keys, client secrets, credentials, private keys, connection strings, and protected state.
- IPv4 and IPv6 candidates are validated with `[Net.IPAddress]::TryParse`, including compressed IPv6 such as `::1` and `2001:db8::1` and mapped forms such as `::ffff:192.0.2.128`.
- Text fallback also handles quoted/multiword assignments, Bearer values, email addresses, usernames, and profile paths.

### Engineering evidence

- `src/app/core/Privacy.psm1`
- `src/app/reports/ReportExport.psm1`
- `tests/test_privacy_reference.py`
- privacy cases in `tests/powershell/Run-WindowsSmokeTests.ps1`

### Required independent regression

- Nested objects and arrays
- JSON keys `Password`, `token`, `Authorization`, `connection_string`, and `api-key`
- Quoted and multiword values
- IPv4, expanded/compressed IPv6, loopback, and IPv4-mapped IPv6
- TXT, JSON, and PDF previews/exports

## New build boundary

- Current corrected build: `2026.08.29-eng-qa11-f010-r2`
- Release authorization: `FALSE`
- Engineering verdict after local source/package testing: eligible only for **Independent Windows QA**
- Windows PowerShell, WinForms, UAC, registry, DPAPI, and installer lifecycle execution remain unverified until QA runs them on Windows 10/11 x64.
