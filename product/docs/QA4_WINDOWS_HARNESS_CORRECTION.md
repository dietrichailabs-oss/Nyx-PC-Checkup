# QA4 Windows Harness HOLD Correction — Introduced in QA5, Preserved in QA7

## Historical intake identity

Independent QA returned:

- `Nyx_PC_Checkup_1.0.0_QA4_Windows_Harness_HOLD_Master_Handoff(1).zip`
- 1,547,058 bytes
- SHA-256 `D34BA21D369B72CD03A7EE7105C7CB5838D5650456D19616C507590877C371F1`
- Verdict: **HOLD — ENGINEERING ACTION REQUIRED FOR WINDOWS QA HARNESS**

The HOLD reviewed QA4 Engineering handoff:

- `Nyx_PC_Checkup_1.0.0_Engineering_QA4_Corrected_Master_Handoff(1).zip`
- 1,548,197 bytes
- SHA-256 `22CB1C4A81BB24B532B90918F14CB268C58586A96AF9FAAB8652820F64D520C7`

Native Windows PowerShell execution terminated with:

`System.ArgumentException: Argument types do not match`

## Correction introduced in QA5

The incompatible shape combined:

- `New-Object System.Collections.Generic.List[...]`; and
- direct array conversion such as `@($script:Results)`, `@($results)`, or `return @($fail)`.

Engineering found the same construct in the shipped runtime, so QA5 was a **new product candidate** rather than a harness-only rewrap.

Across runtime and acceptance code, generic lists now use:

```powershell
$list = [System.Collections.Generic.List[object]]::new()
$list.Add($value)
$materialized = @($list.ToArray())
```

QA5 introduced harness revision `QA5-PS51-1`.

## QA7 preservation

QA7 retains:

- zero `New-Object System.Collections.Generic.List[...]` constructors;
- zero direct `@($genericList)` materializations for discovered generic-list variables;
- corrected `return @($fail.ToArray())` behavior;
- explicit Windows PowerShell 5.1 Desktop-edition guards; and
- dedicated regression tests.

QA7 preserves the generic-list correction and advances the current report identity to `QA9-PS51-6`; QA7 also adds full-graph module composition and installer diagnostic coverage. The generic-list correction itself remains unchanged and mandatory.

Machine-readable evidence remains `evidence/QA4_WINDOWS_HARNESS_CORRECTION.json` and now records both the introduced and current harness revisions.

## Required regression

Independent QA must continue rerunning:

- F-001 privilege boundary;
- F-002 legacy rollback discovery/fail-closed uninstall;
- F-003 report privacy minimization;
- F-004 exact QA2 current-user migration; and
- QA4-WH-001 generic-list behavior under Windows PowerShell 5.1.

## Current QA11 carry-forward

This historical correction remains mandatory under active harness revision `QA17-F014-PS51-17` and root runner `RUN_QA15_WINDOWS_GATE.ps1`.
