# QA15 F-008 first-cell bounds classification

F-008 PRODUCT DEFECT REPRODUCED - QA15 REMAINS FROZEN

The clean normal Hyper-V guest reproduced visible window overflow in the required
FollowWindows / 100% / Home cell. The installed application was observed under
native Windows PowerShell 5.1 x64, in the Console session, after stable visible
layout. No product file, version, runtime sizing rule, or DPI setting was changed.
The remaining matrix stopped under the requested fail-closed policy.

## Numeric evidence

- Capture UTC: 2026-09-26T19:00:23.1517588Z.
- Guest display and uncropped screenshot: 1024 x 768 physical pixels.
- Primary and window-specific WinForms working area: (0, 0)-(1024, 720).
- Native monitor working area: (0, 0)-(1024, 720).
- Form.Bounds and GetWindowRect: (362, 210)-(1354, 898), size 992 x 688.
- Form.DeviceDpi, Graphics.DpiX/Y, and GetDpiForWindow: all 96 (100%).
- UI thread and window contexts: PerMonitorV2; process awareness = 2.
- Left comparison: 362 < 0 = false.
- Top comparison: 210 < 0 = false.
- Right comparison: 1354 > 1024 = true, overflow 330 pixels.
- Bottom comparison: 898 > 720 = true, overflow 178 pixels.

GetWindowRect and GetMonitorInfo were called on the same UI thread and awareness
context. The native rectangle agrees with the managed rectangle. Screenshot
dimensions were not used as a substitute for the guest working area. The full
desktop screenshot independently shows the app extending beyond the desktop.

## Scope and limitations

The external observer invokes the unchanged installed script with native-launcher
child flags and CreateNoWindow console suppression. The native launcher process
itself was not part of this instrumented launch, so its runtime awareness context
was not measured. DPI_AWARENESS.json explicitly records this gap. Do not claim
that native-launcher/UI-process awareness equivalence was measured. This return
proves visible overflow in the instrumented installed UI; Independent QA owns
acceptance and any authorization for a successor candidate.

F008_FIRST_CELL_BOUNDS.json retains the raw capture verdict awaiting review.
CLASSIFICATION.json records the subsequent Engineering evidence review.

## Immutable identity

Build: 2026.09.01-eng-qa15

- Setup: B4F082A79D76E2A7E9452B2717D87698ED136E4D10CFF2D4232DB6E0BF02CD80
- Portable: 6262B9EF383BA3C6AAF0D7BF192B7104EA0CBB3C9799DF55EA30F44A005A370A
- Source ZIP: E9D426CDCEB554AC071532C6079F421B47558A537A037CDC221958945E2AD62B
- Declared source tree: CC58B192CD27F286A041B67510BAF4C7D2097F996D0206DEAE4906BC555A11A0

All 123 source-manifest entries match the frozen Source ZIP. All 60 installed
files shared with the frozen Portable ZIP match; install-state.json is the one
installer-generated extra. See the hash and installed-payload comparison records.

Instrumentation commit: 45e76c5c4968af2c0edef68a6fca2fd895386bbb.
All prior accepted Standard/F-011/F-012/F-010/Elevated results are retained, not
rerun or newly claimed by this bundle.

## Preserved diagnostic attempts

- 01_hidden_launch_invalid: first observer used SW_HIDE; screenshot lacked the
  application and is not used to prove a visible-window failure.
- 02_no_capture_invalid: Shown-event experiment yielded no bounds capture.
- 03_actual_150pct_outside_first_cell: visible overflow at 150%, preserved as an
  out-of-profile diagnostic, not counted as the required 100% first cell.

Only the top-level capture is the authoritative first-cell result. No full-matrix
PASS, Independent QA PASS, or release approval is claimed. Route to Independent
QA; do not rebuild or modify the frozen candidate on the basis of this return.
