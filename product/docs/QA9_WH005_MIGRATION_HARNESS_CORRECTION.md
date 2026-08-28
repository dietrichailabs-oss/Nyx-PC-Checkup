# QA9-WH-005 — Migration Harness Caller-Scope Correction

## Classification

`HARNESS-ONLY CORRECTION — QA9 PRODUCT BYTES FROZEN`

Independent QA HOLD 2 established that QA9 product code still had not been reached. The WH-004 migration harness successfully installed exact immutable QA2 and loaded QA2's DPAPI helpers, then stopped because it required `Initialize-NyxDataDirectories` to remain caller-visible after QA2 `ActionHistory.psm1` force-imported `Paths.psm1`.

## Frozen product identity

- Setup SHA-256: `AB09FCA0574AC6D84A7289B271892EBE4DAF1AD1E0AA4ECBF0670012F070B5EA`
- Portable SHA-256: `8EE1142084C121B9106EED9387C70DC3D06BADCE737F38A8B2847671AEC7FA7C`
- Source SHA-256: `97EBF6A219CC2DEDC9BE975C58C96E5988241D98F5692130BCDE543229F11C82`

## Exact QA2 support identities

- QA2 Setup SHA-256: `FF4C838A1DEF4ABDE39FE89F3A58D023AD25D8C61B99D1836FCB3270F8A301C5`
- QA2 Source SHA-256: `22FCFA7E3050CA854803DD0265109F92444E38E081483A7E2C73DFC0BC522B36`
- QA2 Paths SHA-256: `851323C19AD563291E1B54A25C28A588B7ED151E048E672DCC65761134D8386B`
- QA2 ActionHistory SHA-256: `965143541BFBBE80C2A508F67A496ED3C6E574B241BFD48B667C637168D5751A`

## Correction

`tests/powershell/Run-WindowsQA2MigrationRegression.ps1` no longer depends on caller-visible QA2 Paths exports after ActionHistory is imported.

The harness now reproduces the native module-scope condition explicitly:

1. Import exact QA2 Paths.
2. Verify its exact hash.
3. Observe `Initialize-NyxDataDirectories` visibility immediately after the direct import.
4. Import exact QA2 ActionHistory.
5. Observe the real post-import initializer visibility.
6. Record that observation in the JSON report.
7. Continue without requiring that post-import export.

Fixture path construction is harness-owned and reproduces the exact immutable QA2 Paths contract:

`%LOCALAPPDATA%\Dietrich AI Labs\Nyx PC Checkup`

including:

- `config.json`
- `logs`
- `scans`
- `actions`
- `actions\history.jsonl`
- `actions\disabled-startup`
- `reports`
- `temp`
- `scans\last-scan.json`

The harness verifies the derived root equals the QA2 data root and the derived disabled-startup directory equals the QA2 rollback root. Required fixture directories must be ordinary directories and not reparse points.

The harness still uses immutable QA2 `Protect-NyxState` and `Unprotect-NyxState`, preserving QA2's exact DPAPI journal implementation rather than reimplementing it.

## Required native closure

Independent QA must rerun Standard and confirm:

- no unhandled harness error;
- `HarnessCorrectionRevision = QA9-WH005-1`;
- module-scope observation is present;
- derived QA2 path map is present and exact;
- at least one `CorrectedSetupRuns` entry exists;
- QA9 setup executes;
- QA2 registry and Startup-file rollback restore passes;
- tampered legacy state fails closed;
- QA2 Machine pointer remains rejected;
- corrected uninstall consumes/restores QA2 user rollback before removal.

If Standard passes, QA proceeds to Elevated.

## Evidence boundary

Engineering has not executed Windows PowerShell 5.1 or DPAPI on this Linux host. This correction is not a native PASS claim.

## Prior HOLD 2 identity

- HOLD 2 size: `20986863`
- HOLD 2 SHA-256: `41BA7AC86A1CA50B4FB671EFE611FF677B640F844086E2AAD2979C755969F5D8`
- Sol migration evidence size: `30322`
- Sol migration evidence SHA-256: `8D52DDDC55E555D118D6586C353258CB3C37DF8A9C8A6AB7EF523E9A8F48DBBA`
