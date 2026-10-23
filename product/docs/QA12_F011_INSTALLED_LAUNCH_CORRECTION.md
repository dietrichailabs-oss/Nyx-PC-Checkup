# QA12-F-011 Installed-Launch Correction

## Finding

Independent QA12 reproduced **F-011 — HIGH** on a normal Hyper-V Windows VM: the installed desktop shortcut started the exact native launcher and application PowerShell child, the application logged startup and retained its singleton mutex, but no usable Nyx main window or taskbar entry appeared.

Failed evidence of record:

- Independent QA12 F-011 master: `Nyx_PC_Checkup_1.0.0_Independent_QA12_F011_FAIL_Master_Handoff(1).zip`
- Size: `9,625,568 bytes`
- SHA-256: `97A353077689C05A12598A06B237F8E6871152E342C469A3F8E5350FE9E9253A`
- Failed product commit: `a0d85e6bf03b6a03229bc9f70513f33a8b8d2532`
- Failed Setup: `F785DA20AD4BC55A7EEBD1A63B3C24E364EE874B98B689712E67699F375D88A8`
- Failed Portable: `7C6D1B7E271AA1C94BC552437A2BDF0265FDD57101AD1A62CFB4341D1F9A9803`
- Failed Source: `09344FF558D43855931D97E17F6F4DC1AC37DE193A1D373F74469D0FA58F2403`

## Candidate-lineage clarification

GitHub previously recorded an unpublished QA13 R2 Engineering identity (`6860DA74C06B9A19C94AA7351533CC6B47559900E0F037A7DA31EAB57DA08523`) without committing its complete exact product source to the branch. QA14 supersedes that pre-QA record so only one available, reproducible successor is routed forward. QA14 also keeps hidden installer/uninstaller workers separate from the visible GUI-child contract.

## Root cause

The normal application launcher combined:

1. PowerShell `-WindowStyle Hidden`;
2. `STARTF_USESHOWWINDOW` with `SW_HIDE`; and
3. `CREATE_NO_WINDOW`.

`STARTF_USESHOWWINDOW` supplies the initial show state used by a newly started process. Applying `SW_HIDE` to the PowerShell process that creates the WinForms top-level window could suppress that first application window. `CREATE_NO_WINDOW` is sufficient to suppress the console for this console-subsystem child and does not require hiding the child GUI's first top-level window.

The launcher also did not explicitly select STA even though WinForms and related Windows UI facilities require an STA-compatible application thread.

## Shipped correction

### Native process contracts

`native/win_types.hpp` now exposes two narrow contracts:

- `nyx_run_hidden_worker`: `CREATE_NO_WINDOW` plus hidden first-window state for noninteractive installer/uninstaller workers.
- `nyx_run_gui_child_no_console`: `CREATE_NO_WINDOW` with no forced hidden startup state for the user-facing application child.

The common process routine still waits for the child and returns its exit code so the native launcher exits when the application closes.

### Application launcher

`native/launcher.cpp` now:

- removes `-WindowStyle Hidden`;
- adds explicit `-STA`;
- calls `nyx_run_gui_child_no_console`; and
- retains `-NonInteractive`, `-NoProfile`, `ExecutionPolicy Bypass`, exact script path, safe working directory, and launch-error handling.

### WinForms defense in depth

`src/app/ui/MainWindow.psm1` explicitly sets the main form to:

- `ShowInTaskbar = true`; and
- `WindowState = Normal`.

During `Shown`, it rejects an inherited minimized state, activates the form, and brings it forward. It does not use permanent `TopMost` behavior.

### Singleton preservation

The existing mutex `Local\DietrichAI.NyxPCCheckup.v1` and visible second-launch warning remain unchanged.

## New regression

`tests/powershell/Run-WindowsInstalledLaunchRegression.ps1` must run non-elevated in an interactive disposable Windows desktop. It installs the exact candidate and validates:

- exact installed payload identities;
- desktop shortcut target and working directory;
- actual shortcut launch and parent/child process relationship;
- visible `Nyx PC Checkup` main window within a bounded timeout;
- taskbar eligibility;
- visible second-launch singleton warning while the first UI remains alive;
- clean close of the application child and native launcher;
- direct installed-EXE launch;
- clean no-explicit-STA and explicit-STA script controls;
- immediate fresh visible relaunch; and
- final uninstall and process cleanup.

It records machine-readable process/window/control evidence and captures the visible main window.

## Native boundary

Engineering's Linux build environment can compile and inspect the native PE but cannot prove interactive WinForms visibility or taskbar behavior. The exact immutable successor must pass this regression in a normal interactive Windows VM before Independent QA intake.
