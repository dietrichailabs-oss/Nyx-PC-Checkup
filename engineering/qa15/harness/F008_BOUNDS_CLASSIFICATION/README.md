# QA15 first-cell bounds instrumentation

HARNESS / EVIDENCE ONLY. PRODUCT BYTES UNCHANGED.

The observer runs the unchanged installed PowerShell entry point under Windows
PowerShell 5.1 x64 with the native launcher's STA/noninteractive flags. A debugger
line breakpoint attaches an observation timer immediately before the existing
application message loop. The timer reads the same main form on its UI thread
after three stable, native-visible geometry observations. It does not resize,
move, minimize, or change the form's DPI-awareness context.

The guest launcher suppresses its console with CreateNoWindow, not SW_HIDE.
The original attempted observer used SW_HIDE and its screenshot showed no app;
that capture is not valid proof of a visible-window defect. A subsequent Shown
event experiment produced no capture. These attempts must remain distinguishable
from subsequent stable-visible captures.

GetWindowRect and GetMonitorInfo are compared on the same UI thread and awareness
context. Primary and window-specific WinForms screens, form geometry, actual DPI,
native display mode, screenshot dimensions, and all four bounds comparisons are
recorded separately. RequestedScaling is a request label, not proof of actual DPI.
The required first cell is admissible only when actual window/graphics DPI is 96.

The native launcher itself is not used in this instrumented process; its runtime
DPI awareness is explicitly unobserved. No native-launcher equivalence result
should be inferred beyond the documented child flags and console suppression.

Host scripts preserve the existing VM in a recovery checkpoint, restore the
specified disposable baseline, stage only candidate artifacts and instrumentation,
and collect guest output by read-only mounting after shutdown. They require an
elevated host token. Machine-specific paths and checkpoint IDs are explicit.
Do not run the host reset scripts against another VM without reviewing them.

Runtime evidence and the QA classification belong in a separate evidence commit.
Syntax checks alone do not establish a passing Windows gate.
