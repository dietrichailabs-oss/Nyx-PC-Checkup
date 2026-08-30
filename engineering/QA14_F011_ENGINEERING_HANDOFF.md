# QA14 Engineering Handoff — F-011 Installed Launch Visibility

## Status

**READY FOR NATIVE WINDOWS VM PRE-QA — NOT YET READY FOR INDEPENDENT QA**

Product: `Nyx PC Checkup 1.0.0`  
Build: `2026.08.30-eng-qa14`  
Harness: `QA14-F011-PS51-14`  
Issue: `#2`  
Branch: `eng/f011-installed-launch-visible-window`

QA14 supersedes the unpublished/pre-QA QA13 and QA13 R2 Engineering identities before Independent QA intake. No Windows PASS or approval is carried across identities.

## Exact immutable candidate

```text
Setup:       87F588C84D8BDA276D0B645E9AF66A6795ADE236CFDBC8EB0FA5746F81E814BC
Portable:    D9ECAE4D8AADEDBA005533188AEC9876D1B338865B168670175F43F5F151A8CA
Source:      FE76FE3425582B54E44629131508583D6C1C78102A76065129D8D4215EC06DD7
Source tree: 7B55DCFF4A34D0604AD1923BCFA7E99BD049692514A97D93AC202840B903D769
Handoff:     DEB4AC54093B85FC2EFCE296D4F2ED32B4BB40F30F40D0FB9042CE9688F40683
```

Lightweight handoff size: `1,627,829 bytes`.

## F-011 correction

- The supported UI launcher invokes inbox Windows PowerShell with explicit `-STA`.
- The UI command no longer includes `-WindowStyle Hidden`.
- The Win32 UI-child contract uses `CREATE_NO_WINDOW` only to suppress the console.
- The UI child is not assigned `STARTF_USESHOWWINDOW` / `SW_HIDE`.
- Installer and uninstaller workers retain a separate intentionally hidden-worker contract.
- The WinForms main window is explicitly normal and taskbar-visible and activates when shown.
- The existing per-user singleton mutex remains enforced.

## New native regression

`Run-WindowsInstalledLaunchRegression.ps1` is integrated into the Standard phase of `RUN_QA14_WINDOWS_GATE.ps1` and exercises the actual installed desktop shortcut and native EXE. It checks visible taskbar-eligible main-window creation, process tree/arguments, singleton warning behavior, clean close, immediate relaunch, isolated script controls, screenshots, and bounded process cleanup.

## Engineering verification

- Application PowerShell structural lint: PASS
- Windows-harness PowerShell structural lint: PASS
- Pre-build suite: 186 PASS / 5 expected generated-artifact skips
- Generated-artifact suite: 191/191 PASS
- Clean-source Setup reproduction: exact
- Clean-source Portable reproduction: exact
- Clean-source Source reproduction: exact
- Lightweight archive manifest/SHA256/CRC/path audit: PASS
- Network used: FALSE
- GitHub used by build: FALSE

## Source-control boundary

The exact complete source of record is the Source ZIP identified above. GitHub currently carries the correction records and candidate hashes. Engineering/Codex must import and commit that exact Source ZIP state to this branch before final Independent QA routing; do not reconstruct it from the older QA13 patches.

## Native gates still required

Use clean interactive Windows 10/11 x64 snapshots and inbox Windows PowerShell 5.1 to run:

1. Smoke
2. Standard, including F-011 installed-launch regression
3. Elevated
4. retained F-010 cancellation/relaunch and malformed-state regressions
5. the complete F-008 11-page, three-theme, 100/125/150/200% UI/DPI/accessibility matrix, including 1366x768 at 150%

If those gates pass without changing product bytes, the same exact QA14 candidate may be handed to Independent QA with compact current evidence. A genuine product change creates a new immutable candidate.

Routing remains Engineering -> Engineering/Codex Windows VM pre-QA -> Independent QA. No Sable or Iris gate is part of this cycle.
