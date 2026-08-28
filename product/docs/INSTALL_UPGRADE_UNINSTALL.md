# Nyx PC Checkup 1.0.0 — Install, Upgrade, Repair, and Uninstall

## Fresh install

Run `Nyx_PC_Checkup_1.0.0_Setup.exe` as the target Windows user. The exact supported install root is:

```text
%LOCALAPPDATA%\Programs\Dietrich AI Labs\Nyx PC Checkup
```

Interactive setup offers a desktop shortcut and creates a Start-menu shortcut. Silent QA syntax:

```text
Nyx_PC_Checkup_1.0.0_Setup.exe /quiet /nolaunch
```

Add `/desktop` to request a desktop shortcut in quiet mode. Setup and runtime are per-user and `asInvoker`; QA7 does not request elevation.

For Independent QA branch attribution, Setup also accepts a bounded evidence destination:

```text
Nyx_PC_Checkup_1.0.0_Setup.exe /quiet /nolaunch /diagnostics:"C:\QA-Evidence\Nyx_PC_Checkup_Setup_Diagnostics_Fresh.json"
```

The parent must already be an ordinary directory, the filename must include `Nyx_PC_Checkup_Setup_Diagnostics_`, the destination must not exist, and the extension must be `.json`. Setup uses create-new semantics and never overwrites an existing file. This switch records evidence only; it does not weaken checks or alter installation behavior.

## Upgrade or repair

Run the same or newer setup while Nyx is closed. Setup rejects colliding temporary paths, reparse-backed staging/rollback/target boundaries, and unexpected embedded payload files. It writes and verifies a clean sibling payload, preserves the existing install as a rollback sibling, activates the new payload, and transactionally updates shortcuts/uninstall registration. A finalization failure restores prior external records and the previous install.

Running 1.0.0 setup over 1.0.0 exercises repair/reinstall.

Nyx includes weekly **update availability checking**, not automatic updating. It may notify and open the official website, but it never downloads a package, executes an installer, or replaces installed files.

## Uninstall

Use Windows Installed Apps or:

```text
"%LOCALAPPDATA%\Programs\Dietrich AI Labs\Nyx PC Checkup\Uninstall Nyx PC Checkup.exe"
```

Silent QA syntax preserving local data:

```text
Uninstall Nyx PC Checkup.exe /quiet
```

Explicit silent removal of local data:

```text
Uninstall Nyx PC Checkup.exe /quiet /purgedata
```

### Recovery order

Before removing anything, the uninstaller:

1. validates the exact per-user installation boundary;
2. independently inspects the legacy QA2 ProgramData rollback root;
3. stops with exit `7` if legacy state is present, malformed, unexpected, reparse-backed, or inaccessible;
4. exhaustively validates current-user DPAPI rollback inventory;
5. stops with exit `6` if current-user recovery storage is incomplete or a restore conflicts/fails;
6. restores all supported current-user startup changes;
7. removes uninstall registration and shortcuts;
8. schedules removal of the install root and, only when requested, local data.

QA7 never executes an all-users restoration from LocalAppData and never prompts for UAC. Legacy machine-level recovery must be repaired independently before uninstall can continue.

## Installer exit codes

- `0` — success, or interactive cancellation before a change
- `10` — application is running
- `11` — user installation root unavailable/unsafe
- `12` — payload write/verification failure
- `13` — rollback boundary failure
- `14` — activation failure
- `15` — finalization, payload-manifest, shortcut, or registration failure

When `/diagnostics` is supplied, the record distinguishes the stable branches `RUNNING_INSTANCE`, `LOCALAPPDATA_MISSING`, `INSTALL_PARENT_UNSAFE`, `TEMP_PATH_COLLISION`, `PAYLOAD_STAGE_WRITE_FAILED`, `EXISTING_TARGET_REPARSE`, `EXISTING_TARGET_INVALID`, `ROLLBACK_BOUNDARY_FAILED`, `ACTIVATION_FAILED`, `FINALIZATION_FAILED`, `USER_CANCELLED`, and `SUCCESS`.

## Uninstaller exit codes

- `0` — complete success or interactive cancellation
- `2` — uninstall boundary or worker startup safety failure
- `6` — current-user rollback inventory/restore unresolved; nothing removed
- `7` — legacy machine rollback present or could not be safely validated; nothing removed

A normal successful uninstall leaves no Nyx service, driver, scheduled task, browser setting, firewall rule, updater process, or resident background component because none is installed.
## QA2 current-user rollback upgrade compatibility

Upgrade preserves the separate local-data root. QA7 therefore recognizes exact DPAPI CurrentUser QA2 user journals after upgrade, strictly validates their legacy schema/source/payload boundaries, normalizes valid state in memory, and restores it through the current non-elevated path. Invalid or ambiguous legacy state blocks restoration/uninstall before removal and remains available for evidence or controlled recovery. QA2 Machine-scope pointers are never treated as user-writable state.

