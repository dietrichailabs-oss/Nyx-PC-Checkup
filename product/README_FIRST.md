# Nyx PC Checkup 1.0.0 — Engineering QA11 Corrected Master Handoff

**Publisher:** Dietrich AI Labs  
**Version:** `1.0.0`  
**Build:** `2026.08.29-eng-qa11-f010-r2`  
**Harness revision:** `QA11-F010-PS51-10`  
**Target:** Windows 10/11 x64 using inbox Windows PowerShell 5.1  
**Engineering verdict:** `READY FOR INDEPENDENT WINDOWS QA`  
**Release authorization:** `FALSE`

## Why QA11 exists

Independent QA10 returned **FAIL — RETURN TO ENGINEERING** for **QA10-F-009**, a shipped UI-close lifecycle defect reproduced on native Windows PowerShell 5.1. QA10's `FormClosing` handler passed four optional scan/update path fields directly to `Remove-Item -LiteralPath` even when those fields were still empty strings. PowerShell rejected the empty `LiteralPath` during parameter binding, surfacing an exception through the WinForms `Application.Run` call and a terminal Nyx error dialog.

QA11 changes shipped product bytes and is therefore a new immutable candidate. The exact QA10 FAIL handoff is preserved under `prior_qa/` for regression traceability.

## QA10-F-009 correction

QA11 centralizes optional Nyx temporary-file deletion through `Remove-NyxTemporaryArtifacts` in `core/Paths.psm1`. The helper:

- ignores null/empty/whitespace optional path fields before any `Remove-Item` call;
- derives the exact existing Nyx per-user temp root;
- rejects a reparse-backed temp root or candidate file;
- permits only known scan, update, and action temporary filename patterns;
- requires the candidate's direct parent to equal the exact Nyx temp root; and
- treats optional cleanup failures as bounded cleanup results rather than terminal UI-close failures.

The helper now owns optional cleanup for action request/result files, scan completion, update completion/failure, FormClosing, and application-acceptance scan cleanup. The top-level fatal-error boundary remains intact; QA11 does not hide arbitrary `FormClosing` exceptions.

See `docs/QA10_F009_UI_CLOSE_CORRECTION.md` and `evidence/QA10_F009_UI_CLOSE_CORRECTION.json`.

## QA9-F-008 responsive UI correction preserved

QA11 retains QA10's DPI/working-area sizing, docked global actions, wrapped labels, Startup/Apps action placement, horizontal grid scrolling/tooltips, compact Cleanup layout, widened/scrollable Settings controls, and focus scroll-into-view behavior. The final native visual matrix remains mandatory because QA10 failed before QA could reach it.

## Native Windows gates required

Engineering cannot execute WinForms or Windows PowerShell 5.1 on this Linux host and therefore does **not** claim native UI/process-close PASS. Independent QA must rerun the exact QA11 bytes on Windows 10/11 x64, including:

- Standard Smoke, privilege/rollback, exact QA2 migration, and installer lifecycle;
- Elevated privilege/rollback and installer lifecycle;
- the QA10-F-009 close lifecycle matrix (immediate close, updates disabled, update enabled/before output, Quick Check close, scan-cancel close, update success/failure close, repeated close/relaunch, no residual process, and exact temp-root boundary); and
- the complete QA9-F-008 final UI/accessibility matrix across Follow Windows/Dark/Light at 100%, 125%, 150%, and 200%, including 1366×768 and the prior 150% failure class.

## Product and safety continuity

QA11 retains the complete Version 1 local-first health/checkup functionality, user-directed cleanup, reversible current-user startup changes, conservative Unknown states, privacy-safe local report export, notification-only Dietrich AI Labs weekly update availability checking, clean per-user packaging, and carried-forward exact QA2 migration regressions.

No website update manifest is published by this Engineering candidate. No executable is automatically downloaded or installed.

## Handoff contents

- exact QA11 Setup, Portable, and Source artifacts;
- root `RUN_QA11_WINDOWS_GATE.ps1` plus four Windows PowerShell 5.1 suites;
- exact QA2 migration fixtures;
- manifests, SHA-256 sums, SBOM, licenses/notices;
- Engineering test, PE, packaging, F-008, and F-009 correction evidence;
- exact QA10 FAIL evidence plus historical QA evidence needed for regression traceability; and
- explicit Engineering → Independent QA routing.

## Historical regression identities retained by the QA11 gate

- QA4 Windows-harness HOLD identity: `D34BA21D369B72CD03A7EE7105C7CB5838D5650456D19616C507590877C371F1`; QA4 Engineering identity `22CB1C4A81BB24B532B90918F14CB268C58586A96AF9FAAB8652820F64D520C7`. The proven symptom was `Argument types do not match`; the correction used `.ToArray()` and required a **new product candidate**.
- QA5 Engineering identity: `B72A0BAD2094F37EAE1E853794A72763A9ACF76D3B27E776AC5FB8647F19B349`; native QA evidence `5E6DC04424216650720A408BF8E99AAF52FD6EF20DE35489F76D0740ADE36298`. Mandatory regressions remain `QA5-WIN-001`, `QA5-WIN-002`, `QA5-ORCH-001`, and `QA5-ENC-001`, including the automatic-variable collision.
- QA6 FAIL identity: `E81C56200A409B83E3A1B04A045D4726BE41C24494ED459FB9B91EAB4CACE324`; nested Windows evidence `38B28BB535067EB0B8508A364F6D9EE1DB6FC068D72608F83CFD34F8D28D41C7`. `QA6-F-005` requires `RuntimeComposition.psm1`, preservation of `New-NyxCheckResult`, and immutable-QA2 evidence labeled `HarnessInferenceFromImmutableQA2Source` where appropriate.
- Historical suite wording retained for traceability: `normal-user smoke and privacy/update`; `privilege-boundary and legacy rollback`; `exact QA2-to-QA9 user rollback migration`; and `installer lifecycle`. The active QA11 migration suite carries forward WH-004/WH-005/WH-006.

Run the root manifest-bound gate with Windows PowerShell 5.1, for example:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\RUN_QA11_WINDOWS_GATE.ps1" -Phase Smoke
```

The active harness revision is `QA11-F010-PS51-10`.
