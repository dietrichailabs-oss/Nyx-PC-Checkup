# QA5 Native Windows Failure Correction — Introduced in QA6, Preserved in QA7

## Intake identity

Native Windows execution reviewed the exact QA5 Engineering candidate:

- File: `Nyx_PC_Checkup_1.0.0_Engineering_QA5_Corrected_Master_Handoff.zip`
- Size: 1,564,979 bytes
- SHA-256: `B72A0BAD2094F37EAE1E853794A72763A9ACF76D3B27E776AC5FB8647F19B349`
- Setup SHA-256: `A3753F22AAFF3C46B51731A1D61E5CD75CF9FB4C1FCD504373B33F6C1538A883`
- Portable SHA-256: `3F75BD8F3622DE227DC858112B69DC4501341D7892FA7041038D2D8C21A40A38`
- Source SHA-256: `2CDF6C78C39E555FAC2D10AACA244AA274E43A20BD6C83FB65628DBC4FC24240`

Returned evidence:

- File: `QA5_MASTER_HANDOFF_20260824_184906.zip`
- Size: 7,842 bytes
- SHA-256: `5E6DC04424216650720A408BF8E99AAF52FD6EF20DE35489F76D0740ADE36298`
- Decision: **QA5 FAIL — reproducible defects; route to Engineering**

Recorded target environment:

- Windows: `Microsoft Windows NT 10.0.26200.0`
- Windows PowerShell: `5.1.26100.9168`
- Edition: `Desktop`
- Smoke/Standard context: non-administrator

The supplied evidence archive contains seven files. Its text report lists a Standard `QA5_WINDOWS_RUN_SUMMARY.json`, but that file is not present in the archive. The surviving smoke and privilege JSON reports are sufficient to establish the two Engineering defects below. QA6’s runner correction also prevents this class of incomplete evidence summary.

## QA5-WIN-001 — ambiguous variable interpolation

### Evidence

Windows PowerShell 5.1 reported:

```text
ActionHistory.psm1:202
Variable reference is not valid. ':' was not followed by a valid variable name character.
Consider using ${} to delimit the name.
```

QA5 source contained:

```powershell
throw "Unexpected data exists in rollback $ActionId: $($child.Name)"
```

### Root cause

Inside an expandable string, PowerShell interpreted the colon immediately following `$ActionId` as part of a scoped-variable form. The Linux structural linter treated expandable-string contents as opaque and therefore missed the target parser rule.

### QA6 correction

```powershell
throw ("Unexpected data exists in rollback {0}: {1}" -f $ActionId,$child.Name)
```

The format operator avoids ambiguous interpolation entirely.

## QA5-WIN-002 — `$Error` automatic-variable collision

### Evidence

The smoke report recorded:

```text
System.Management.Automation.SessionStateUnauthorizedAccessException:
Cannot overwrite variable Error because it is read-only or constant.
```

QA5 used:

```powershell
foreach($error in @($errors)) { ... }
```

### Root cause

PowerShell variable names are case-insensitive. `$error` therefore refers to the protected automatic variable `$Error`; the loop attempted to overwrite it before the harness could report parser failures.

### QA6 correction

The parser loop now uses:

```powershell
$scriptFile=$_.FullName
$parserTokens=$null
$parserErrors=$null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    $scriptFile,
    [ref]$parserTokens,
    [ref]$parserErrors
)
foreach($parseError in @($parserErrors)) { ... }
```

This also removes reliance on the outer pipeline’s `$_` inside the nested loop.

## QA5-ORCH-001 — runner did not always finalize evidence

### Evidence

The Standard text report says migration execution did not complete and claims a Standard summary was included, but the archive has no Standard summary file.

### Root cause

The QA5 runner merged child error output into a pipeline while its own `$ErrorActionPreference` was `Stop`. A child parser error could therefore terminate the parent before the runner wrote its summary or packaged complete evidence.

### QA6 correction

`tests/powershell/RUN_QA9_WINDOWS_GATE.ps1`:

- temporarily changes only the child-invocation preference to `Continue`;
- captures child output and `$LASTEXITCODE`;
- restores the caller preference in `finally`;
- records launch errors separately;
- verifies the manifest-bound Setup, Portable, Source, QA2 fixtures, harnesses, and runner;
- performs a native Windows PowerShell 5.1 parse preflight before any harness action;
- validates that every expected JSON report exists, parses, carries `HarnessRevision='QA9-PS51-6'`, and reports internally consistent totals;
- continues remaining required harnesses;
- always writes `QA6_WINDOWS_RUN_SUMMARY.json` after successful initialization; and
- packages the complete phase evidence directory.

## QA5-ENC-001 — deterministic Windows PowerShell 5.1 source encoding

The QA5 evidence proved that Linux-only text inspection was not a substitute for target-interpreter behavior. During the expanded QA6 sweep, Engineering also removed BOM-less non-ASCII UTF-8 from shipped and harness PowerShell files. Windows PowerShell 5.1 can otherwise decode those bytes using the active ANSI code page.

QA6 therefore requires every `.ps1` and `.psm1` file to be either ASCII-clean or UTF-8 with a BOM. UI glyphs and the Unicode filename regression fixture are constructed from explicit character code points, preserving behavior without ambiguous source bytes. `tools/ps_lint.py` and `tests/test_powershell51_parser_safety.py` enforce the rule.

## Static prevention

QA6 adds two independent prevention layers.

### Structural linter

`tools/ps_lint.py` now rejects:

- unqualified `$Variable:` inside expandable strings;
- `foreach` binding to `$Error`;
- direct assignment to `$Error`;
- parameters named `$Error`;
- `Set-Variable` attempts targeting `Error`; and
- BOM-less non-ASCII UTF-8 source that Windows PowerShell 5.1 may decode inconsistently.

The linter still states honestly that it is not a replacement for the native Windows PowerShell parser.

### Python regression suite

`tests/test_powershell51_parser_safety.py`:

- scans every shipped `.ps1` and `.psm1` file plus every Windows harness;
- fails on either proven defect pattern;
- asserts the exact corrected source shapes;
- injects synthetic bad examples and proves the linter rejects them; and
- injects corrected examples and proves they pass.

## Candidate consequence

`ActionHistory.psm1` is shipped runtime code, and the smoke harness plus QA runner are part of the acceptance package. QA5 cannot be re-labeled or rewrapped. QA6 is a new immutable candidate with new Setup, Portable, Source, source-tree, manifest, and outer handoff identities.

## Required QA regression

QA must run the exact current QA7 bytes with Windows PowerShell 5.1 and confirm that the QA6-introduced corrections remain effective:

1. the runner verifies the extracted handoff inventory;
2. smoke parsing reaches the real assertions without `$Error` collision;
3. `ActionHistory.psm1` imports without parser error;
4. every report contains `HarnessRevision='QA9-PS51-6'`;
5. Standard execution continues through all configured harnesses even if one fails;
6. the native parse-preflight report exists and contains zero diagnostics;
7. each child result validates its expected JSON report and revision rather than relying only on process exit code;
8. the phase summary is always produced after successful runner initialization;
9. all historical F-001 through F-004 and QA4-WH-001 regressions remain passing; and
10. the complete functional/UI/installer matrix is executed.

## Engineering boundary

Engineering could reproduce both source defects exactly from the preserved Windows evidence and could add deterministic static gates. This Linux host cannot execute Windows PowerShell 5.1 or the Windows installer/registry/DPAPI/UAC paths. Native confirmation remains the responsibility of Independent QA.

## Current QA11 carry-forward

This historical correction remains mandatory under active harness revision `QA17-F014-PS51-17` and root runner `RUN_QA15_WINDOWS_GATE.ps1`.
