# Independent QA6 Failure Correction — Engineering QA7

## QA input identity

Independent QA returned:

- `Nyx_PC_Checkup_1.0.0_Independent_QA6_FAIL_Master_Handoff(1).zip`
- Size: `26,479 bytes`
- SHA-256: `E81C56200A409B83E3A1B04A045D4726BE41C24494ED459FB9B91EAB4CACE324`
- Verdict: `FAIL — RETURN TO ENGINEERING`

The exact native-Windows evidence reviewed by QA was:

- `QA6_MASTER_HANDOFF_20260824_193051.zip`
- Size: `17,941 bytes`
- SHA-256: `38B28BB535067EB0B8508A364F6D9EE1DB6FC068D72608F83CFD34F8D28D41C7`

Environment recorded in that evidence:

- Windows: `Microsoft Windows NT 10.0.26200.0`
- Windows PowerShell: `5.1.26100.9168`
- PSEdition: `Desktop`
- Standard/non-elevated execution

## Confirmed finding QA6-F-005

The parser preflight passed, but the real smoke path failed after the runtime import graph loaded:

```text
CommandNotFoundException: New-NyxCheckResult is not recognized
```

The failure reproduced in both the isolated Smoke phase and Standard phase. The Standard-user privilege-boundary suite separately passed 11/11.

## Root cause

The QA6 runtime had no single owner for shared module composition. Multiple modules imported dependencies from within their own module scope, commonly using:

```powershell
Import-Module <shared module> -Force
```

Under Windows PowerShell 5.1, a nested forced re-import can remove or replace a previously imported module session state. Commands already exported to the caller can therefore disappear even though each source file parses and each module appears valid in isolation.

`Models.psm1` was a repeated shared dependency. Its public `New-NyxCheckResult` command disappeared after the complete graph loaded.

## Engineering QA7 correction

QA7 adds:

`src/app/core/RuntimeComposition.psm1`

This module is the sole application-module composition root. It owns:

- the exact ordered module inventory;
- each module’s expected exported functions;
- bounded load profiles for diagnostics, updates, uninstall, actions, scans, and UI;
- exact-path conflict detection;
- ordinary-file and reparse checks;
- global-scope import without `-Force`;
- cumulative command-surface verification after every module layer; and
- final command-surface verification.

Every runtime `.psm1` other than the composition root contains zero `Import-Module` statements. Entry points and workers request a profile from the composition root instead of loading dependencies themselves.

A module already loaded from the correct path but missing an expected export causes a deterministic failure. QA7 refuses to conceal that state through an implicit reload.

## Acceptance coverage

The Windows smoke suite now verifies:

1. all runtime files parse under the actual Windows PowerShell 5.1 parser;
2. full composition completes;
3. every cumulative dependency layer retains its expected commands;
4. `New-NyxCheckResult`, `New-NyxUnknownResult`, `Get-NyxStatusLabel`, `Get-NyxStatusSymbol`, and `Get-NyxResultSummary` remain available after the full graph;
5. a second composition call is idempotent; and
6. the real application acceptance path launches twice, with each launch running the actual Quick Check worker and validating a read-only result set.

Dedicated Python regressions independently compare every runtime module’s `Export-ModuleMember` declaration against the composition inventory and reject nested module ownership. All four native Windows harnesses and the manifest-bound runner identify `HarnessRevision='QA9-PS51-6'`.

## Installer gate clarification QA6-G-006

QA did not classify the QA2 and QA6 exit-11 observations as proven product defects. Both installers stopped early on the same local/non-clean host, and the supplied evidence could not identify the exact branch.

QA7 therefore adds two complementary evidence layers without weakening fail-closed behavior:

- native branch-specific setup diagnostics for every success/failure path; and
- a prelaunch harness record covering `%LOCALAPPDATA%`, path resolution, component attributes, ACL/SDDL, reparse state, and bounded write capability.

The native setup record distinguishes:

- `RUNNING_INSTANCE`
- `LOCALAPPDATA_MISSING`
- `INSTALL_PARENT_UNSAFE`
- `TEMP_PATH_COLLISION`
- `PAYLOAD_STAGE_WRITE_FAILED`
- `EXISTING_TARGET_REPARSE`
- `EXISTING_TARGET_INVALID`
- `ROLLBACK_BOUNDARY_FAILED`
- `ACTIVATION_FAILED`
- `FINALIZATION_FAILED`
- `USER_CANCELLED`
- `SUCCESS`

The exact QA2 fixture is immutable and cannot emit the new record. Any QA2 branch interpretation is clearly labeled `HarnessInferenceFromImmutableQA2Source`.

## Remaining native gate

Engineering’s Linux environment cannot execute Windows PowerShell 5.1, WinForms, registry/DPAPI/UAC paths, or the native installer lifecycle. The exact QA7 bytes must therefore be rerun by Independent QA on clean disposable Windows 10/11 x64 snapshots.

The Elevated phase remains unexecuted until QA runs it from an elevated Windows PowerShell 5.1 session on a separate clean snapshot.

## Current QA11 carry-forward

This historical correction remains mandatory under active harness revision `QA11-F010-PS51-10` and root runner `RUN_QA11_WINDOWS_GATE.ps1`.
