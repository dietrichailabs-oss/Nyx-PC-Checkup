# Codex Windows Pre-QA — Nyx PC Checkup QA13 R2 F-011

Repository: `dietrichailabs-oss/Nyx-PC-Checkup`  
Branch: `eng/f011-installed-launch-visible-window`  
Issue: `#2`  
Build: `2026.08.30-eng-qa13-r2`  
Harness: `QA13-R2-PS51-14`

## Mission

Use clean disposable Windows 10/11 x64 VMs and inbox Windows PowerShell 5.1 to validate the exact frozen QA13 R2 candidate. Do not rebuild or modify product bytes unless a genuine product defect is reproduced.

## Exact identities

```text
Setup:       60850A9E949E4B9AD50639E8250C8C132AFB9B027CF87FDC95F3091F835A065E
Portable:    4B289846756CA26EBCC2E0CD2E658B8A90F0F0509627F2329B913C506B375229
Source:      B7512BACBA50D33A6FB87A3B0617E2967049AE3ABC196DFFDDA1823833A88389
Source tree: 22D2D530C88FEB89F9D49617C24F283A730AB957AB096E3C15900D5C72A17F39
Launcher:    F3D39845D2C5E9C2056F8E660403A40662C133F210C38520FECEF34876A63558
App script:  888C7635B03CC951B413AEACBCC663C3E62F2229F2838D3D8F8809591D561648
Handoff:     6860DA74C06B9A19C94AA7351533CC6B47559900E0F037A7DA31EAB57DA08523
```

Verify all hashes before execution. Stop on any mismatch.

## Required VM runs

1. `RUN_QA13R2_WINDOWS_GATE.ps1 -Phase Smoke`
2. `RUN_QA13R2_WINDOWS_GATE.ps1 -Phase Standard -DestructiveCleanVmAcknowledged` from a non-elevated clean snapshot.
3. `RUN_QA13R2_WINDOWS_GATE.ps1 -Phase Elevated -DestructiveCleanVmAcknowledged` from a separate elevated clean snapshot.
4. Preserve/rerun the F-010 cancellation/relaunch and malformed-state regressions against these exact bytes.
5. Complete the full F-008 installed-app UI/accessibility matrix: Follow Windows, Dark, and Light at 100%, 125%, 150%, and 200%, including 1366x768 and the prior constrained 150% class.

The Standard phase must execute `Run-WindowsInstalledLaunchRegression.ps1` and prove:

- actual desktop shortcut opens one visible usable main window;
- direct installed EXE opens one visible usable main window;
- PowerShell UI child contains `-STA`;
- child does not contain `-WindowStyle Hidden`;
- no visible PowerShell console;
- second launch shows the singleton warning;
- first window remains visible and usable;
- clean close exits launcher and child;
- immediate relaunch works;
- screenshots are captured; and
- no residual Nyx process remains.

## Defect policy

- Harness/evidence-only defect: preserve product bytes and correct only the harness.
- Product defect: preserve exact evidence, fix on the Engineering branch, add focused regression coverage, and create a new immutable candidate. Never overwrite QA13 R2.
- Passing execution: do not rebuild. Return the exact current candidate plus small current evidence ZIPs.

## GitHub and output

Update issue #2 with exact hashes, VM identities, PowerShell version, all test totals, F-011 screenshots, F-008 matrix totals, and the final Engineering pre-QA status. Do not upload recursive historical QA bundles.

Return the exact evidence package path and either `READY FOR INDEPENDENT QA` or `BLOCKED`. Do not claim Independent QA PASS.

Routing remains Engineering -> Independent QA only. Codex is Engineering execution tooling, not an additional approval role.
