# QA23 F-020 grid-focus correction

QA22 remains frozen. QA23 source build identity is 2026.09.27-eng-qa24;
harness identity is QA24-F021-PS51-24. Candidate acceptance is not asserted.

The QA22 native failure recorded a selected row below the outer page viewport.
Both prior focus-tree handlers only reacted to control Enter. A DataGridView
does not re-enter when its current row or cell changes. Its native scrolling
does not know that a parent panel clips its much larger viewport.

All application grids use Controls.New-NyxGrid: Checkup; category pages
(Security, Updates, Backup, System); Storage results, folders and largest files;
Startup; Apps; and Cleanup. The factory now registers a shared, per-grid helper.
The generic focus trees defer grids to that helper instead of scrolling the
whole oversized control back to its origin. Non-grid focus behavior is unchanged.

The helper waits for key processing to settle, reveals the cell inside the
grid, maps its visible rectangle through each scrolling ancestor, and adjusts
only the offset necessary to expose it. Timer/event state lives on the grid,
not expired function locals, and does not replace page Tag state. Disposal
stops/disposes the timer. No Scroll/MouseWheel subscription overrides manual
scrolling. No broad exception handler masks geometry errors.

Deterministic PS5.1 tests use actual WinForms controls/key processing, constrained
outer geometry, 40 rows and eight columns. Geometry scales are not claimed as
native DPI acceptance. Installed 200%/1366x768 reproduction remains mandatory,
followed by the ordered gates from Issue #12. No QA22 test count transfers as
QA23 acceptance. Build only after source tests pass; use a fresh build directory
so the builder cannot clean QA22 output folders.
