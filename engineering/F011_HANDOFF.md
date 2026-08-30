# Engineering Handoff — QA12-F-011

## Finding

**F-011 — HIGH — installed launch can create a live invisible singleton instance with no usable main window.**

The exact r4 candidate is failed for release. Do not relabel or reuse its immutable candidate identities.

## Frozen failing product commit

`a0d85e6bf03b6a03229bc9f70513f33a8b8d2532`

QA documentation commits after that SHA do not change `product/`; use the dedicated F-011 Engineering branch created from the frozen r4 product commit.

## Required correction behavior

A fresh current-user install on a supported normal Windows 10/11 x64 desktop must satisfy all of the following:

1. Desktop shortcut launches exactly one Nyx instance.
2. A usable main application window becomes visible promptly.
3. A normal taskbar presence exists while the main window is open.
4. The native launcher must not leave a permanently invisible child instance holding the singleton mutex.
5. A second launch while the visible app is open may show the existing single-instance warning.
6. After clean close, launcher and child PowerShell processes exit; a fresh relaunch must open normally.
7. No console flash is required, but hiding the console must not hide or suppress the WinForms application.

## Root-cause investigation

Start with:

- `product/native/launcher.cpp`
- `product/native/win_types.hpp`
- installed PowerShell startup arguments
- apartment state / `-STA` behavior
- interaction of `STARTF_USESHOWWINDOW`, `SW_HIDE`, `CREATE_NO_WINDOW`, and PowerShell `-WindowStyle Hidden`

Do not simply remove single-instance protection.

Do not globally weaken error handling or StrictMode.

## Mandatory clean controls

Each control must start only after every prior Nyx launcher/PowerShell/worker process is confirmed gone.

A. Installed desktop shortcut
B. Installed native EXE directly
C. Installed script with native-launcher-equivalent arguments, without `-STA`
D. Same installed script with `-STA`

For each record:

- process tree and full child command line;
- launcher/PowerShell exit behavior;
- visible main-window evidence;
- taskbar evidence;
- logs;
- screenshot;
- singleton state;
- clean close and relaunch.

The prior Codex B2/B3/B4 controls cannot be used to decide root cause because the invisible B1 instance remained alive and caused each later control to hit the legitimate single-instance warning.

## Regression gates

Preserve the exact r4 green campaign without rerunning unchanged suites until a new candidate exists:

- Smoke 122/122
- Standard privilege 12/12
- QA2 migration 244/244
- Standard lifecycle 44/44
- Elevated privilege 14/14
- Elevated lifecycle 50/50
- F-010 cancel/relaunch 110/110
- F-010 malformed state 16/16

After product bytes change, the successor must rerun all required native gates.

## F-008

After the successor launches normally from the installed shortcut on a normal Windows VM, complete the full F-008 visual/accessibility matrix before returning the candidate to Independent QA.

## Packaging

Produce a new immutable Setup / Portable / Source / source-tree identity from clean allowlisted staging and return one Engineering master handoff.

Engineering may report READY FOR INDEPENDENT QA but may not self-approve release.
