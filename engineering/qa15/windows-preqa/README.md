# QA15 Windows pre-QA evidence

Build: `2026.09.01-eng-qa15`

Disposition: `ENGINEERING HOLD - F008 ENVIRONMENT/EVIDENCE INCOMPLETE`

The QA15 product candidate remains frozen. No Setup, Portable, Source ZIP, source-tree, product source, runtime, native, configuration, or build-metadata bytes were changed.

Completed gates:

- F-012 Settings/theme regression: 17/17 PASS.
- F-010 cancellation/relaunch native matrix: 110/110 PASS.
- F-010 malformed persisted-state native matrix: 16/16 PASS.
- Elevated privilege/rollback: 14/14 PASS.
- Elevated installer lifecycle: 50/50 PASS.

F-008 is not complete. The real installed GUI workflow passed all 33 functional checks, but the Windows Sandbox session exposed 100% scaling at 2033x1112 instead of the required 150% at 1366x768. The required 100%, 125%, 150%, and 200% matrix therefore has 0 PASS, 33 FAIL, and 99 NOT-RUN cells. The 33 recorded cells are retained as FAIL because the window-bounds condition was not satisfied in the invalid guest display configuration. This is an environment/evidence hold and is not classified here as a product defect.

Frozen identities:

- Setup SHA-256: `B4F082A79D76E2A7E9452B2717D87698ED136E4D10CFF2D4232DB6E0BF02CD80`
- Portable SHA-256: `6262B9EF383BA3C6AAF0D7BF192B7104EA0CBB3C9799DF55EA30F44A005A370A`
- Source ZIP SHA-256: `E9D426CDCEB554AC071532C6079F421B47558A537A037CDC221958945E2AD62B`
- Source-tree SHA-256: `CC58B192CD27F286A041B67510BAF4C7D2097F996D0206DEAE4906BC555A11A0`
- Input handoff SHA-256: `AFD5F37CB5DBA78BC69F65535AF181F5E2CEBCC6DAFF2864951D0A48E2CD3D8F`

The harness-only timestamp correction is commit `8dd3ea03fb50f56866ea284506f29202860d3f97`. It compares independently parsed `DateTimeOffset` values as UTC instants. Product bytes are unchanged.
