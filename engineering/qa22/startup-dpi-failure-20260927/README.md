# QA22 Engineering stop-on-failure return

Status: STOPPED_PRODUCT_UI_FAILURE / RETURN TO INDEPENDENT QA.
This is not Independent QA's final classification and is not release approval.
No source correction, product rebuild, successor candidate, or candidate repackage.

## Failure

Startup keyboard selection becomes hidden below the page viewport at native
200% custom scaling / 1366x768. The third selected row is partly clipped; the
fourth selected row (OneDrive) and its keyboard focus are completely off-screen.
The page does not scroll to reveal the selected row. Manual outer-page scrolling
reveals OneDrive selected, proving navigation occurred while its feedback was
hidden. This violates the required keyboard-focus visibility/reachability gate.
Mouse scrolling is a workaround; we do NOT claim all mouse actions are inaccessible.

Observed in the current light-rendered app mode. The exact saved theme option was
not captured, so no Follow Windows versus Light attribution is asserted. No full
F-008 matrix cell is counted PASS. This failure arose during F-015 DPI coverage.
Root cause is not established by screenshots; no source changes were attempted.

## Reproduction

1. Use the installed frozen QA22 app in the disposable Nyx guest.
2. Configure Windows custom scaling to 200%, start a new session, retain 1366x768.
3. Scroll the left navigation and open Startup.
4. Scroll the page down until Refresh is visible and activate Refresh.
5. Press Tab to enter the first grid cell. The outer viewport aligns the grid top.
6. Press Down twice: the third row is selected but clipped below the viewport.
7. Press Down once more: the selected fourth row and focus are no longer visible.
8. Scroll the outer page manually downward: OneDrive appears selected with focus.

The temporary missing-target row precedes OneDrive. It is a normal current-user
Run entry pointing at a nonexistent EXE. The helper, fixture identities, snapshots,
and removal records are preserved in the prior functional checkpoint and this
native session. No product file was changed to create this fixture.

## Evidence

DPI200_REFRESH.png: working Refresh after scrolling at 200%.
DPI200_GRID_THIRD_ROW_CLIPPED.png: keyboard-selected third row clipped.
DPI200_GRID_FOURTH_ROW_FOCUS_OFFSCREEN.png: fourth selection/focus invisible.
DPI200_MANUAL_SCROLL_REVEALS_SELECTED_ONEDRIVE.png: manual scroll reveals selection.
DPI200_NATIVE_RESOLUTION.png: Windows reports 1366x768 and custom scaling enabled.
DPI200_APPLIED_CUSTOM_SCALE.png: custom 200 after new session, no pending sign-out.

The disabled 125% dropdown label is NOT the active custom scale.
Native logs show this installed session started 2026-09-27T20:39:06.4254762Z and
closed 2026-09-27T20:45:06.1658356Z. No crash or StrictMode exception was observed.
Live pre-shutdown records at 16:46:04-05 EDT report no workers or scan artifacts.
The fixture was removed at 20:45:06Z. OneDrive remained enabled. Installed before/
after inventories contain 61 files each, zero SHA-256 differences. The previous
QA startup shortcut was restored; VM was left off, not reverted or reset.

## Exact frozen candidate

Source commit: 958813267b6f69466770701816146de234cf1388
Build: 2026.09.27-eng-qa22
Harness: QA22-F019-PS51-22
Setup SHA256: 618D28B330DC2A501DC5B0CFB22C9AFB2EB23876260A1B490A297966FA3CA2C7
Portable SHA256: E607E726606B64BE3AE1F040587AE1866A90800066B78228D9130A9E32BFF4CF
Source ZIP SHA256: 59309A6341EC6FF8C18E0157DEA325BCCAE2D971F82888A8E4B12062211C3712
Source tree identity: 4A3A45CA0F6DA6C67A17DA5AF164CB90B260114FBE3B84D31CCE105572302F50
The three archive hashes were freshly checked after the failure. The source-tree
identity is the existing frozen identity, not a new recomputation in this session.

## Counts and routing

Earlier F-015 functional checkpoint: 13 positive observations at 100%.
This 200% focus sequence: Refresh PASS; navigation scrolling PASS; selected-row
visibility FAIL. Diagnostic manual scrolling confirmed the hidden selection.
F-015 complete acceptance: NOT PASS. 125% and 150% remain untested here.
F-008 full matrix: 0/132 complete cells; stopped before the full matrix.
Standard, Smoke, privilege/lifecycle, F-011, F-012, F-010 and Elevated: not run in
this continuation because of the first genuine product UI failure.
F-016 focused completion remains preserved; no unrelated completed gates rerun.

Engineering -> Independent QA via Issue #11 only. Independent QA assigns the
formal defect/classification and decides the next correction order.

## Non-nested prior evidence

Repository: dietrichailabs-oss/Nyx-PC-Checkup
Branch: eng/f019-category-page-single-result-count
Release: qa22-f019-candidate-20260927
F-016 evidence commit: 8d1134193e54e72219ed981d8e017a19c6e37660
Asset: QA22_F016_TIMING_PASS_20260927_161446.zip (39630 bytes)
SHA256: B07BBDB49F72462EC41BFE1B7765D8229F05D0F611B2B40CA93FB7D14601DF6A
F-015 functional commit: 7b929a6c9176756d8067328e5cf6c6109726c853
Asset: QA22_F015_FUNCTIONAL_PARTIAL_20260927_1640.zip (1798532 bytes)
SHA256: AC3CC23B103E7881C878DE00F52AB52C4000523C139CAC77261FDD8D0F3010D9
This new ZIP is evidence-only; it does not nest historical ZIPs or product archives.
