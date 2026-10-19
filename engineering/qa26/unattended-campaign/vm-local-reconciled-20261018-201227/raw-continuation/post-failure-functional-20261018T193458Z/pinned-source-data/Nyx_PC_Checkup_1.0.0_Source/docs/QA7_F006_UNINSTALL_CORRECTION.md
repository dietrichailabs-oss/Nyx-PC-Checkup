# QA7-F-006 Uninstall Correction — QA8

## Prior finding

Independent QA confirmed on native Windows that the frozen QA7 product returned exit `0` for both ordinary uninstall and `/quiet /purgedata`, yet the installed application root still existed after the documented 20-second wait.

QA classification: **HIGH / RELEASE BLOCKER**.

The root-cause trace showed:
- the native uninstaller started the PowerShell worker with the install root as its process current directory;
- the worker later started detached `cmd.exe` without an explicit safe working directory;
- the detached cleanup inherited a current directory inside the tree it was asked to remove.

## QA8 correction

QA8 changes product bytes.

### Native uninstaller
`native/uninstaller.cpp` now:
- obtains `%SystemRoot%`;
- constructs `%SystemRoot%\System32` as `safeCwd`;
- invokes the PowerShell uninstall worker through `nyx_run(..., safeCwd, TRUE)`;
- never uses the install root as the worker current directory.

### Uninstall worker
`src/app/workers/UninstallWorker.ps1` now:
- validates `%SystemRoot%\System32` as an ordinary non-reparse directory;
- rejects any cleanup working directory equal to or beneath the install root;
- starts detached `cmd.exe` with explicit `-WorkingDirectory $safeWorkingDirectory`;
- uses `-PassThru -ErrorAction Stop` and verifies a valid process identity;
- returns exit `8` when safe cleanup scheduling cannot be established;
- writes a temporary failure marker if the detached process later finds the install root still present;
- revalidates `/purgedata` against the exact expected Nyx LocalAppData data root;
- rejects reparse-backed purge roots.

## Preserved semantics

QA8 does not weaken:
- rollback-first ordering;
- current-user rollback restoration;
- exit `6` for unresolved current-user rollback obligations;
- exit `7` for legacy machine-level rollback obligations;
- default local-data retention;
- explicit `/purgedata` behavior;
- install-root exact-boundary checks;
- reparse protections.

## Regression requirements

Independent QA must rerun:
1. Smoke.
2. Standard privilege/rollback.
3. Fresh install and repair.
4. Rollback conflict → uninstall exit `6`, with application preserved.
5. Clear conflict → uninstall exit `0`, startup restored, install root absent.
6. Reinstall.
7. `/quiet /purgedata` → exit `0`, install root absent, local data absent.
8. Registration and shortcut cleanup.
9. No service or scheduled task.
10. Elevated legacy ProgramData rollback / exit `7`.
11. Exact immutable QA2 migration on a prerequisite-valid Windows profile.

Engineering does not claim native Windows PASS on this host.
