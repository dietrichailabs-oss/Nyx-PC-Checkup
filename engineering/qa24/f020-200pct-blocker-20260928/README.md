# QA24 installed UI blocker return

Engineering status: BLOCKED. Independent QA owns the final disposition.

Frozen build: 2026.09.27-eng-qa24
Harness: QA24-F021-PS51-24
Source: 31ff35dead242485bad2ab74c4838e8a5d41cb7f

## Reproduction

1. Use the already installed frozen QA24 in the normal Nyx Windows 11 VM.
2. Set Windows custom scaling to 200%, sign out/in, and use1366x768.
3. Open Apps with populated inventory. Scroll to Search applications.
4. Focus Search, press Tab into the grid, then Ctrl+End.
5. The final selected row is visible, but its rightmost focused cell is only a narrow strip; its value is not readable.
6. End does not correct it. Moving the outer page horizontal scrollbar right moves the grid but does not restore readable cell width.
7. Ctrl+Home then Ctrl+End reproduces the same failure.

Screenshots21,22,23,24 preserve failure and diagnostic controls.
Screenshots02/03 record Windows resolution and applied custom scaling.
This is a product UI readability finding, not evidence of a crash.
Exact root cause is not proven. No source fix was attempted.

## Scope and counts

OBSERVED_CHECKS.json records17 positive observations and1 failed observation.
These are observation cases, not a complete automated suite or accepted F008 cells.
Startup focus/navigation and Refresh observations are positive but incomplete.
Full F008 acceptance remains0/132 cells in this return.
Acceptance stopped at the observed Apps failure; later gates were not run.

No startup records were modified. No cleanup action was executed.
VM remains running with the failure displayed, preserving the interactive state.
No fresh guest log/event collection or current-session installed payload inventory is included.

## Immutable identity and prior evidence

All three frozen candidate archive hashes were rechecked and unchanged.
The source-tree hash in ENGINEERING_RESULT.json is the previously recorded frozen identity.
Candidate bytes are NOT nested/repackaged here:
https://github.com/dietrichailabs-oss/Nyx-PC-Checkup/releases/tag/qa24-f021-candidate-20260927

Prior verified native F021 result:
https://github.com/dietrichailabs-oss/Nyx-PC-Checkup/blob/d52ad72a6bc2469195dd4a3acae1a87d766c5c4e/engineering/qa24/f021-native/F021_RESULT.json

Prior evidence reports216/216 Python,2/2 lint,125/125 native deferred callbacks,740/740 geometry.
Those results are not substituted for installed DPI acceptance.

Routing: Engineering to Independent QA via Issue13. No release approval is claimed.
