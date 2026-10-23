# QA25 F-022 Apps column readability

QA24 is immutable. QA25 build2026.09.28-eng-qa25, harnessQA25-F022-PS51-25.

## Root cause and measured baseline

The real Apps page in Windows PowerShell5.1 source geometry reproduced the
QA24 failure: Reported size widths140,98,57,20 at scales1,1.25,1.5,2.
At200%, its FillWeight fell to11.876483 while Application rose to195.949219.
Set-NyxDeviceGeometry sets columns sequentially while Fill is active, allowing
WinForms redistribution to skew subsequent widths. Default minimums5/6/8/10
do not protect readability. Outer scrolling cannot repair a20px column.

## Correction

Apps alone uses AutoSizeColumnsMode=None, ScrollBars=Both and logical widths
and minimums240/200/150/130/150 for Name/Publisher/Version/Date/Size.
Existing device geometry scales these. No fonts, data or keyboard controls
are removed. Filtering clears rows, not column policy.

The initial implementation exposed a second interaction: setting MinimumWidth
can clamp Width immediately. The shared geometry helper now captures the
original Width and minimum before setting either, preventing double scaling.
It does not globally change other grids from Fill mode.

## Cross-page source audit and remaining acceptance

Apps: explicit readable minimum policy; real-page geometry exercised.
Startup: existing explicit widths/None/Both retained; shared focus tests passed.
Checkup and category pages: results grid uses Fill with deliberate weights.
Storage: results, folder and largest-file grids also use Fill.
Cleanup: editable checkbox grid uses Fill with deliberate weights.
These Fill grids require native constrained-DPI column-readability audit;
no complete cross-page native acceptance is claimed from synthetic geometry.
No global change to Fill policy was made.

## Results and limitations

Real Apps source geometry:1328/1328 PASS after scaling-order correction.
Shared synthetic grid focus regression:PASS.
Deferred Apps/Cleanup callback regression:125/125 PASS.
Clean Python source suite:215 PASS,5 missing-artifact skips.
Structural lint:2/2 PASS.

Initial harness dependency error and initial double-scaling failure are retained
in Engineering evidence, not relabeled as passing runs. Source geometry
emulates scales; it is NOT installed native Windows DPI acceptance.
Page reconstruction uses Clear-NyxPage then Show-NyxPage Apps. Real navigation
away/back, all pages, actual fonts/DPI and the132-cell matrix remain native gates.
Focused installed200%/1366x768 must run first, with stop-on-first-product-failure.


## Current successor identity (QA26)

Historical candidate identities above remain unchanged. The current successor build is 2026.10.02-eng-qa26; its active harness is QA26-F023-PS51-26. QA25 remains frozen; native successor acceptance is required.
