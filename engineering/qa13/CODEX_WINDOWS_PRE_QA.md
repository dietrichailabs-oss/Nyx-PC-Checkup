# Codex Windows Pre-QA — Nyx PC Checkup QA13 F-011

Repository: `dietrichailabs-oss/Nyx-PC-Checkup`  
Branch: `eng/f011-installed-launch-visible-window`  
Issue: `#2`  
Build: `2026.08.30-eng-qa13`  
Harness: `QA13-PS51-13`

## Primary mission

Use clean disposable Windows 10/11 x64 VMs and inbox Windows PowerShell 5.1 to validate the exact frozen QA13 candidate. Do not rebuild or modify product bytes unless a genuine product defect is reproduced.

## Exact identities

- Setup SHA-256: `447483FFED71E7622BBBBB18678670DF61D15AE18794F9BFAC8695BBF33115D2`
- Portable SHA-256: `03781C0DE2891735A3F8F131363811E176BC1A5EBA73F7DBDD715E2F43BBD413`
- Source SHA-256: `A255864D23F49184908DF293D61034D09A83F853DBA831B7F08E482D2CCDC69A`
- Source-tree SHA-256: `C32856DB6CEA481B4864C65520D255FDF237986D1BB4953C81095CFAD4894BBC`
- Installed launcher SHA-256: `F3D39845D2C5E9C2056F8E660403A40662C133F210C38520FECEF34876A63558`
- Installed app script SHA-256: `0FD7B75C1C450EF59B61BA11803D154638149C486C11D732B944B2FAE6CC9624`

Verify all hashes before execution. Stop on any mismatch.

## Required VM runs

1. `RUN_QA13_WINDOWS_GATE.ps1 -Phase Smoke`
2. `RUN_QA13_WINDOWS_GATE.ps1 -Phase Standard -DestructiveCleanVmAcknowledged`
3. `RUN_QA13_WINDOWS_GATE.ps1 -Phase Elevated -DestructiveCleanVmAcknowledged` on a separate elevated snapshot.
4. Rerun/preserve the F-010 cancellation/relaunch and malformed-state matrix against these exact bytes.
5. Complete the full F-008 installed-app UI/accessibility matrix: Follow Windows, Dark, Light at 100%, 125%, 150%, and 200%, including 1366x768 and the prior 150% constrained class.

The Standard phase must execute `Run-WindowsInstalledLaunchRegression.ps1` and prove: desktop-shortcut launch visible, direct EXE relaunch visible, child command contains `-STA`, no `-WindowStyle Hidden`, no visible PowerShell console, singleton warning preserved, clean close, clean immediate relaunch, screenshots captured, and no residual process.

## Defect policy

- Harness/evidence-only defect: preserve candidate bytes and correct only the harness.
- Product defect: preserve exact evidence, fix on the Engineering branch, add regression coverage, and create a new immutable candidate. Never overwrite QA13.
- Passing execution: do not rebuild. Return the exact candidate plus small current evidence ZIPs.

## Final response

Return exact verified hashes, branch/commit, VM identities, PowerShell version, Smoke/Standard/Elevated totals, F-010 result, F-011 installed-launch result, F-008 matrix totals and screenshots, any defect, whether bytes changed, and final Engineering status `READY FOR INDEPENDENT QA` or `BLOCKED`.

Routing remains Engineering -> Independent QA only. Codex is Engineering execution tooling, not an additional approval role.
