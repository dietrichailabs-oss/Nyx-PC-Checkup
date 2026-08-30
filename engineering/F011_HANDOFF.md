# Engineering Handoff — QA12-F-011

## Finding

**F-011 — HIGH — installed launch can create a live invisible singleton instance with no usable main window.**

Frozen failing r4 product commit:

`a0d85e6bf03b6a03229bc9f70513f33a8b8d2532`

## Reproduction

On a normal Hyper-V Windows VM, a fresh current-user installation launched from the desktop shortcut starts the native launcher and child Windows PowerShell process, writes `PC Checkup started.`, starts the automatic update worker, and holds the per-user singleton mutex, but produces no visible Nyx main window or taskbar entry through the full bounded observation period.

Later launches correctly report that Nyx is already open because the first invisible instance remains alive.

## Primary root-cause area

Investigate:

- `product/native/launcher.cpp`
- `product/native/win_types.hpp`
- installed PowerShell startup arguments
- apartment state / `-STA`
- `STARTF_USESHOWWINDOW`, `SW_HIDE`, `CREATE_NO_WINDOW`
- PowerShell `-WindowStyle Hidden`

The launcher currently combines hidden PowerShell arguments with hidden Win32 process-creation flags and waits for the child indefinitely.

Do not remove single-instance protection as the fix.

## Required clean controls

Every control must begin only after all prior Nyx launcher / PowerShell / worker processes are confirmed exited.

1. desktop shortcut;
2. installed native EXE;
3. installed script with native-launcher-equivalent arguments without `-STA`;
4. same installed script with `-STA`.

Capture process tree, command line, exit behavior, visible window/taskbar evidence, logs, screenshot, singleton state, clean close, and relaunch.

The prior QA12 B2/B3/B4 controls are root-cause-inconclusive because the hidden B1 singleton was still alive.

## Regression

Preserve and rerun after product bytes change:

- Smoke 122/122
- Standard privilege/rollback 12/12
- QA2 migration 244/244
- Standard lifecycle 44/44
- Elevated privilege/rollback 14/14
- Elevated lifecycle 50/50
- F-010 cancellation/relaunch 110/110
- F-010 malformed persisted state 16/16

Then complete the full F-008 visual/accessibility matrix from the installed application on a normal Windows VM.

## Packaging

Produce a new immutable Setup / Portable / Source / source-tree identity from clean allowlisted staging and return one Engineering master handoff to Independent QA.
