# QA26 F-023: keyboard-operable grid primary actions

QA25 remains frozen at source f55c0d3bda6a99a20d218a2a390f217963a0d9be.
This correction belongs only to eng/f023-result-detail-keyboard-activation.

The common results grid and Storage largest-file grid now share a validated
primary-action dispatcher. Enter is explicitly classified as an input key,
then consumed before default DataGridView row movement. Mouse double-click
selects the clicked row/cell and uses the same dispatcher.

Grid-owned action state survives constructor return. Disposed grids, absent
cells, invalid/header rows, new rows and missing Tag objects do not dispatch.
An in-progress action blocks reentrant dialogs. A finally block releases that
state and restores the original live cell and grid focus without swallowing
action exceptions. Existing grid-focus scrolling is requested afterward.

Only the Enter key without modifiers is the primary action. Navigation and
selection changes do not open dialogs. Cleanup checkbox semantics are unchanged.

Mouse-only UI audit: the application source had two mouse-specific action
bindings, common result details and Storage largest-file Explorer selection.
Both now use the shared registration. Standard Button Click actions retain
their normal keyboard activation. The audit does not claim full native UI
accessibility acceptance; all required installed and matrix gates remain.

Test-QA26ResultKeyboardActivation.ps1 constructs the real result grids after
their constructor returns, invokes registered keyboard/mouse handlers, verifies
exact original result identity, real modal closure/focus restoration, repeated
activation, reentrancy, navigation negatives, empty/null/header/disposed cases,
page recreation, and real Storage construction with observed Explorer actions.
Reflected event integration is explicitly separate from installed keyboard input.

Build identity: 2026.10.02-eng-qa26
Harness identity: QA26-F023-PS51-26

Independent QA owns final classification and release approval.
