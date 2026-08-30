# Independent QA12 — F-011 Installed Launch Failure

## Verdict

**FAIL — release blocked / return to Engineering**

Finding: **F-011 — HIGH — installed launch can create a live invisible singleton instance with no usable main window**

Frozen failed candidate:

```text
Build: 2026.08.29-eng-qa11-f010-r4
Harness: QA11-F010-PS51-12
Commit: a0d85e6bf03b6a03229bc9f70513f33a8b8d2532
Setup: F785DA20AD4BC55A7EEBD1A63B3C24E364EE874B98B689712E67699F375D88A8
Portable: 7C6D1B7E271AA1C94BC552437A2BDF0265FDD57101AD1A62CFB4341D1F9A9803
Source: 09344FF558D43855931D97E17F6F4DC1AC37DE193A1D373F74469D0FA58F2403
Source tree: 8D30FED1DC605E4FE317AB8DFB7E15C4A37F4A39D55F75D59A81A64B93716C68
```

## Normal Windows VM reproduction

Environment: normal Hyper-V Windows VM, user `Nyx`; Windows Sandbox was not used as the primary classification environment.

1. Exact installed launcher and app-script hashes verified.
2. Desktop shortcut points to installed `Nyx PC Checkup.exe` with the install root as working directory.
3. Launch shortcut once from a clean state.
4. Native launcher PID `3288` starts child PowerShell PID `6544`.
5. Child command line:

```text
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File <installed app\NyxPCCheckup.ps1>
```

6. Both launcher and child remain alive for the full ~17 second sampled observation.
7. The child launches the automatic update worker.
8. App log records `PC Checkup started.`
9. No Nyx main window or taskbar item is produced.
10. A later launch displays `Nyx PC Checkup is already open for this Windows user.`, proving the invisible first instance still owns the per-user singleton.

This is a shipped installed-launch failure, not a Windows Sandbox-only condition.

## Likely root-cause area

`product/native/launcher.cpp` builds the child PowerShell command with `-WindowStyle Hidden` and calls `nyx_run(..., TRUE)`.

`product/native/win_types.hpp` implements hidden launch with both:

- `STARTF_USESHOWWINDOW` / `SW_HIDE`
- `CREATE_NO_WINDOW`

and then waits indefinitely for the child process.

This is the primary root-cause area to investigate, but QA does not require Engineering to assume it is the only cause. The B3/B4 diagnostic controls were contaminated by the still-running invisible first singleton instance, so Engineering must reproduce each launch control from a truly clean process state.

## F-010 status

F-010 remains green in the exact r4 native evidence:

- Smoke 122/122 PASS
- Standard privilege/rollback 12/12 PASS
- QA2 migration 244/244 PASS
- Standard lifecycle 44/44 PASS
- Elevated privilege/rollback 14/14 PASS
- Elevated lifecycle 50/50 PASS
- F-010 cancellation/relaunch 110/110 PASS
- F-010 malformed persisted-state matrix 16/16 PASS

Do not regress those gates.

## Required successor

Engineering must create a new immutable candidate. F-008 remains open because the installed app never reached a usable visible main window on the normal VM.

Independent QA alone issues PASS / CONDITIONAL PASS / HOLD / FAIL.
