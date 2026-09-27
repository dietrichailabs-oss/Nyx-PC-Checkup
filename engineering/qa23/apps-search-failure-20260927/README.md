# QA23 Engineering stop: Apps search unhandled exception

The installed QA23 candidate raised an unhandled Windows Forms exception when `n` was entered into Apps > Search applications:

`The variable '$render' cannot be retrieved because it has not been set.`

Expanded details identify `System.Management.Automation.RuntimeException`. One occurrence was observed; tests stopped immediately. No source fix, rebuild, or successor candidate was made.

## Execution context

Disposable Windows Nyx VM, user Nyx, native PowerShell 5.1. Session followed Windows custom scaling change from 200 to 150 percent and sign-out/sign-in. Guest environment and installed-payload records accompany this failure when collected. Existing app configuration and persisted scan state were retained and recorded by the harness, not treated as a factory-clean profile.

The exact observed path was Startup functional checks, then Apps, focus Search applications, type `n`. No additional reproductions were attempted after the exception. The unbound render variable is consistent with a deferred-callback lifetime problem, but no source correction was attempted during this acceptance run.

## Positive observations before stopping

At 200 percent, Startup's historical third/fourth-row clipping did not recur. Six-row Down/Up traversal, Home/End, Ctrl+Home/End, Page Up/Down, Refresh, away/back, and manual-scroll/keyboard interaction had positive observations.

At 150 percent, six-row Down traversal, horizontal End/Home and Shift+Tab cell movement were visible. Startup's disposable missing-target fixture disabled with rollback, remained disabled after Refresh, and re-enabled. A missing target produced the expected unavailable message; a valid OneDrive target opened File Explorer with the executable selected. An all-users Disable attempt produced no action or prompt. These observations are not a complete F-015/F-020 acceptance pass.

## Counts and unrun gates

Python 211/211; structural 2/2; native PS5.1 simulated-geometry checks 740/740. Native geometry tests do not replace installed actual-DPI tests.

F-020 incomplete. F-015 partial. F-008 0/132 fully accepted cells; the complete matrix was not started. Standard, F-011, F-012, F-010 and Elevated were not run on QA23 because execution stopped at the first genuine product failure. No QA22 results are inherited.

Engineering returns failure evidence to Independent QA. Independent QA owns PASS/HOLD/FAIL and release approval.
