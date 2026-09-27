# Nyx PC Checkup 1.0.0 — QA14 F-011 Engineering Candidate

**Publisher:** Dietrich AI Labs  
**Version:** `1.0.0`  
**Build:** `2026.09.27-eng-qa20`  
**Harness revision:** `QA20-F017-PS51-20`  
**Target:** Windows 10/11 x64 with inbox Windows PowerShell 5.1  
**Engineering state:** `READY FOR NATIVE WINDOWS VM PRE-QA`  
**Release authorization:** `FALSE`

## Why QA13 exists

Independent QA12 returned **FAIL — RETURN TO ENGINEERING** for **F-011**, a shipped installed-launch defect reproduced in a normal Hyper-V Windows VM. The supported desktop shortcut started the native launcher and application PowerShell process, the application logged startup and held its per-user singleton, but no usable main window or taskbar application appeared.

The frozen failed r4 candidate remains historical evidence. QA14 changes shipped native-launcher and UI bytes and is therefore a new immutable product candidate.

## Candidate-lineage clarification

GitHub previously recorded an unpublished QA13 R2 Engineering identity (`6860DA74C06B9A19C94AA7351533CC6B47559900E0F037A7DA31EAB57DA08523`) without committing its complete exact product source to the branch. QA14 supersedes that pre-QA record so only one available, reproducible successor is routed forward. QA14 also keeps hidden installer/uninstaller workers separate from the visible GUI-child contract.

## F-011 correction

The previous launcher combined three independent hiding mechanisms:

- PowerShell `-WindowStyle Hidden`;
- Win32 `STARTF_USESHOWWINDOW` / `SW_HIDE`; and
- Win32 `CREATE_NO_WINDOW`.

That contract could hide the first WinForms top-level window along with the console.

QA14 separates the two process-launch purposes:

- `nyx_run_hidden_worker` remains available for installer/uninstaller worker processes that have no user-facing window.
- `nyx_run_gui_child_no_console` uses `CREATE_NO_WINDOW` to suppress the PowerShell console **without** applying a hidden startup show state to the child GUI.
- The normal application launcher removes `-WindowStyle Hidden` and explicitly invokes Windows PowerShell with `-STA`.
- The main WinForms form explicitly remains a normal, taskbar-visible window and reasserts that state during `Shown` without forcing always-on-top behavior.
- The existing per-user singleton mutex remains unchanged.

See `docs/QA12_F011_INSTALLED_LAUNCH_CORRECTION.md`.

## New native Windows gate

`Run-WindowsInstalledLaunchRegression.ps1` installs the exact candidate and tests the actual supported entry points. It verifies:

1. installed launcher/script hashes and shortcut target/working directory;
2. desktop-shortcut launch from clean process state;
3. one visible, taskbar-eligible `Nyx PC Checkup` main window;
4. visible second-launch singleton behavior while the first instance remains usable;
5. clean close of child and native launcher;
6. direct installed-EXE launch;
7. isolated no-explicit-STA and explicit-STA script controls;
8. immediate fresh visible relaunch; and
9. uninstall cleanup with no bounded Nyx process left behind.

The gate captures a main-window screenshot and machine-readable process/window evidence. The manifest-bound Standard runner executes it after the historical functional/lifecycle suites.

## Mandatory native pre-QA

This Linux Engineering host compiles and structurally tests Windows binaries but cannot execute WinForms, Windows PowerShell 5.1, interactive taskbar/window behavior, registry/DPAPI/UAC, or installer lifecycle operations. Therefore this candidate is **not yet routed to Independent QA**.

Engineering/Codex must run the exact frozen QA14 bytes on clean interactive Windows 10/11 x64 VMs and complete:

- Smoke;
- Standard privilege/rollback;
- exact QA2 migration;
- Standard installer lifecycle;
- the new F-011 installed-launch gate;
- Elevated privilege/rollback and lifecycle;
- F-010 cancellation/relaunch and malformed-state regressions; and
- the still-open complete F-008 theme/DPI/accessibility matrix.

If those gates pass without product-byte changes, the same exact QA14 candidate may be handed to Independent QA. Any product correction creates a new immutable candidate.

## Product continuity

QA14 carries forward the complete local-first Version 1 functionality, conservative status model, user-directed cleanup, reversible current-user startup actions, privacy-safe report export, notification-only Dietrich AI Labs weekly update availability checking, and all historical F-001 through F-010 regression boundaries.

No website manifest is published for this candidate. No executable is silently downloaded or automatically installed.

## Windows runner

From the extracted Engineering handoff, use inbox Windows PowerShell 5.1:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\RUN_QA15_WINDOWS_GATE.ps1" -Phase Smoke
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\RUN_QA15_WINDOWS_GATE.ps1" -Phase Standard -DestructiveCleanVmAcknowledged
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\RUN_QA15_WINDOWS_GATE.ps1" -Phase Elevated -DestructiveCleanVmAcknowledged
```

Standard must run non-elevated in an interactive desktop session. Elevated must use a separate clean/reverted snapshot.

## Routing

Current route: **Engineering → Engineering/Codex Windows VM pre-QA → Independent QA**.

Independent QA alone may return `PASS`, `CONDITIONAL PASS`, `HOLD`, or `FAIL`. No additional reviewer or gate is designated in this cycle.

## Historical regression identities retained

These immutable identities remain regression references without being recursively embedded in the lightweight transport:

- QA4 Windows-harness HOLD: `D34BA21D369B72CD03A7EE7105C7CB5838D5650456D19616C507590877C371F1`; QA4 Engineering: `22CB1C4A81BB24B532B90918F14CB268C58586A96AF9FAAB8652820F64D520C7`. The proven symptom was `Argument types do not match`; the `.ToArray()` correction required a **new product candidate**.
- QA5 Engineering: `B72A0BAD2094F37EAE1E853794A72763A9ACF76D3B27E776AC5FB8647F19B349`; native evidence: `5E6DC04424216650720A408BF8E99AAF52FD6EF20DE35489F76D0740ADE36298`. Mandatory boundaries include `QA5-WIN-001`, `QA5-WIN-002`, `QA5-ORCH-001`, `QA5-ENC-001`, and the PowerShell automatic-variable collision.
- QA6 FAIL: `E81C56200A409B83E3A1B04A045D4726BE41C24494ED459FB9B91EAB4CACE324`; nested Windows evidence: `38B28BB535067EB0B8508A364F6D9EE1DB6FC068D72608F83CFD34F8D28D41C7`. `QA6-F-005`, `New-NyxCheckResult`, `RuntimeComposition.psm1`, and `HarnessInferenceFromImmutableQA2Source` remain mandatory.

Historical suite wording retained for traceability: `normal-user smoke and privacy/update`; `privilege-boundary and legacy rollback`; `exact QA2-to-QA9 user rollback migration`; and `installer lifecycle`.
