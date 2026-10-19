# QA10-F-009 — UI Close Lifecycle Correction

## Finding

Independent QA10 returned **FAIL** after native Windows Standard execution reproduced a shipped UI lifecycle defect. `MainWindow.psm1` initialized optional scan/update temporary path fields to empty strings and the `FormClosing` handler passed all four directly to `Remove-Item -LiteralPath`. Windows PowerShell 5.1 rejected the empty string during parameter binding, surfacing an exception through `[Windows.Forms.Application]::Run($form)`.

## QA11 correction

QA11 introduces one bounded temporary-artifact cleanup contract in `core/Paths.psm1`: `Remove-NyxTemporaryArtifacts`.

The helper:

- accepts null, empty, and whitespace optional path values without forwarding them to `Remove-Item`;
- derives the exact per-user Nyx temp root from the existing path map;
- requires that root to be an ordinary, non-reparse directory when present;
- accepts only known Nyx UI/worker temporary filename patterns for scan, update, and action files;
- requires every candidate's direct parent to equal the exact Nyx temp root;
- rejects reparse-backed candidate files;
- deletes only ordinary allowed files;
- returns bounded cleanup counts for test evidence; and
- treats optional cleanup as best-effort without weakening the application's top-level error boundary.

The same helper now owns optional cleanup in:

- action request/result completion;
- update-worker launch failure and completion;
- scan completion;
- `FormClosing`; and
- the application acceptance Quick Check probe.

QA11 does **not** remove the top-level user-visible fatal-error handling and does not swallow arbitrary `FormClosing` exceptions. The fix is limited to the optional temporary-file cleanup contract.

## Native Windows regression hooks

The QA11 Smoke harness performs direct zero-safe and outside-root cleanup assertions and launches the real WinForms application twice through an explicit acceptance-only close probe:

- automatic update disabled;
- automatic update enabled and due, closing before an update result is required to exist.

The probe uses the same real `Shown -> FormClosing -> Application.Run` lifecycle and must exit cleanly with terminal evidence. Independent QA must additionally cover Quick Check close, scan cancellation close, update success/failure close, repeated relaunch, residual-process observation, and the full QA9-F-008 visual matrix.

## Engineering boundary

Engineering can statically validate and package the corrected PowerShell/WinForms source on this Linux host, but it cannot execute Windows PowerShell 5.1, WinForms, Windows display scaling, or native process-close behavior. Independent QA must execute the exact immutable QA11 bytes on disposable Windows 10/11 x64.
