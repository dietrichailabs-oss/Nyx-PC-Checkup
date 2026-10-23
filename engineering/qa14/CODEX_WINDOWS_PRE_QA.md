# Codex Windows Pre-QA — Nyx PC Checkup QA14 F-011

Repository: `dietrichailabs-oss/Nyx-PC-Checkup`  
Branch: `eng/f011-installed-launch-visible-window`  
Issue: `#2`  
Build: `2026.08.30-eng-qa14`  
Harness: `QA14-F011-PS51-14`

## Mission

Use clean interactive disposable Windows 10/11 x64 VMs and inbox Windows PowerShell 5.1 to validate the exact frozen QA14 candidate. Do not rebuild or modify product bytes unless a genuine product defect is reproduced.

## Exact identities

```text
Handoff:     DEB4AC54093B85FC2EFCE296D4F2ED32B4BB40F30F40D0FB9042CE9688F40683
Setup:       87F588C84D8BDA276D0B645E9AF66A6795ADE236CFDBC8EB0FA5746F81E814BC
Portable:    D9ECAE4D8AADEDBA005533188AEC9876D1B338865B168670175F43F5F151A8CA
Source:      FE76FE3425582B54E44629131508583D6C1C78102A76065129D8D4215EC06DD7
Source tree: 7B55DCFF4A34D0604AD1923BCFA7E99BD049692514A97D93AC202840B903D769
```

Verify all identities before execution. Stop on any mismatch.

## GitHub source import

Extract the exact Source ZIP above and commit its complete authored source state to this branch before final QA routing. Preserve generated-artifact boundaries and do not import build, cache, log, VM, or recursive historical handoff directories. Report the remote commit SHA that corresponds to the exact QA14 source.

## Required VM execution

Use `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`.

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\RUN_QA14_WINDOWS_GATE.ps1" -Phase Smoke
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\RUN_QA14_WINDOWS_GATE.ps1" -Phase Standard -DestructiveCleanVmAcknowledged
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\RUN_QA14_WINDOWS_GATE.ps1" -Phase Elevated -DestructiveCleanVmAcknowledged
```

Standard must run non-elevated in an interactive desktop session. Elevated must use a separate clean snapshot.

The Standard phase must execute `Run-WindowsInstalledLaunchRegression.ps1` and prove:

- actual desktop shortcut opens one visible usable Nyx main window;
- direct installed EXE opens one visible usable main window;
- UI PowerShell child includes `-STA`;
- UI child excludes `-WindowStyle Hidden`;
- no visible PowerShell console is produced;
- second launch shows the singleton warning while the first main window remains usable;
- clean close exits launcher and child;
- immediate relaunch opens visibly again;
- screenshots are captured; and
- no bounded Nyx process remains.

Repeat the four diagnostic controls only from clean process state: shortcut, native EXE, script without explicit STA, and script with STA.

Rerun the retained F-010 cancellation/relaunch and malformed persisted-state gates against these exact bytes.

Complete the full F-008 installed-app matrix across all 11 pages:

- Follow Windows, Dark, Light
- 100%, 125%, 150%, 200%
- mandatory 1366x768 at 150%
- clipping, overlap, action reachability, grid scrolling/tooltips, Tab/Shift+Tab, visible focus, focus scroll-into-view, dialogs, status meaning without color, resizing, and clean close/relaunch

Capture every failure and representative PASS states. Produce a machine-readable matrix.

## Defect policy

- Harness/evidence-only defect: preserve QA14 product bytes and correct only the harness.
- Genuine product defect: preserve evidence, fix source, add focused regression, and create a new immutable candidate. Never overwrite QA14.
- Passing execution: do not rebuild. Return the same QA14 bytes plus compact current evidence to Independent QA.

Update issue #2 with VM identity, PowerShell version, exact totals, screenshots/matrix paths, remote source commit, and final Engineering pre-QA status.

Do not claim Independent QA PASS. Routing remains Engineering -> Independent QA only; Codex is Engineering tooling. No Sable or Iris.
