# QA9-WH-004 — Migration Harness Correction

## Classification

`HARNESS-ONLY CORRECTION — QA9 PRODUCT BYTES FROZEN`

Independent QA's QA9 Standard run established:

- Smoke: `97/97 PASS`
- Privilege / rollback: `12/12 PASS`
- Installer lifecycle: `44/44 PASS`
- QA2 migration: `8/9 HARNESS BLOCKED`

QA9-WH-004 occurred before QA9 setup or migration code ran. The prior migration harness invoked the immutable QA2 `Get-NyxStartupApplications`, which retains QA2's historical Windows PowerShell 5.1 generic-list materialization defect.

## Product-byte preservation

This reissue does not modify the frozen QA9 product:

- Setup SHA-256: `AB09FCA0574AC6D84A7289B271892EBE4DAF1AD1E0AA4ECBF0670012F070B5EA`
- Portable SHA-256: `8EE1142084C121B9106EED9387C70DC3D06BADCE737F38A8B2847671AEC7FA7C`
- Source SHA-256: `97EBF6A219CC2DEDC9BE975C58C96E5988241D98F5692130BCDE543229F11C82`

No immutable QA2 artifact was changed.

## Correction

`tests/powershell/Run-WindowsQA2MigrationRegression.ps1` now creates harness-owned QA2 legacy rollback state without calling either:

- `Get-NyxStartupApplications`
- `Disable-NyxStartupApplication`

The corrected harness:

1. Installs the exact immutable QA2 setup.
2. Pins the installed QA2 `core/ActionHistory.psm1` to SHA-256 `965143541BFBBE80C2A508F67A496ED3C6E574B241BFD48B667C637168D5751A`.
3. Imports only the QA2 fixture-support modules needed for local data paths and protected state.
4. Builds the exact 17-property QA2 current-user rollback schema with no `JournalVersion`, `JournalScope='User'`, `OwnerSid=''`, and Boolean `RequiresElevation=$false`.
5. Protects the state with the immutable QA2 `Protect-NyxState`, which uses `DPAPI1:`, CurrentUser DPAPI, entropy `DietrichAI.NyxPCCheckup.v1`, and UTF-8 JSON.
6. Immediately re-reads and decrypts each generated journal with the immutable QA2 `Unprotect-NyxState` implementation.
7. Revalidates the exact property set and user-scope boundary before QA9 is installed.
8. For registry fixtures, verifies the original HKCU Run value exists before journaling and is absent after simulated QA2 disable.
9. For Startup-folder fixtures, verifies an ordinary source file, exact rollback payload path, source absence after move, and backup length/SHA-256 identity.
10. Runs the existing QA2→QA9 restore, tamper rejection, machine-pointer rejection, and uninstall-consumption scenarios.

The migration report keeps the shared QA9 suite revision `QA9-PS51-6` and additionally records:

`HarnessCorrectionRevision='QA9-WH004-1'`

This avoids invalidating the already-passing QA9 Smoke, privilege, and installer harness revisions while making the corrected migration harness individually identifiable by manifest hash and report metadata.

## Engineering validation on the Linux host

- PowerShell structural lint over all handoff harnesses: `PASS`
- Corrected migration harness contains QA2 startup enumerator calls: `0`
- Corrected migration harness contains QA2 startup disable calls: `0`
- Immutable QA2 ActionHistory hash is pinned: `PASS`
- DPAPI protect/unprotect self-check is required before QA9 installation: `PASS` by structural inspection
- QA9 Setup/Portable/Source hashes unchanged: `PASS`
- Native Windows PowerShell 5.1 execution: `NOT AVAILABLE ON ENGINEERING HOST`

Independent QA/Sol must execute the corrected migration harness on native Windows PowerShell 5.1 to close QA9-WH-004. Engineering does not claim that Windows runtime result in advance.

Local command output summary: `evidence/QA9_WH004_LOCAL_VALIDATION.txt`
