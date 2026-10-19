# Nyx PC Checkup QA27 Engineering candidate

Build: `2026.10.19-eng-qa27`  
Harness: `QA27-F024-PS51-27`  
Base source: `0303a78a06f67252c86634cd73f1e4bda32dd3cc`  
Branch: `eng/f024-pdf-export-empty-lines`

This is a new immutable successor for F-024. QA26 bytes, branch, reports and
failure evidence stay frozen. Read docs/QA27_F024_PDF_EXPORT.md first.

PDF accepts intentional blank lines, consecutive blank lines and an empty
collection without losing spacing. Null/non-string input is rejected before
output; escaping, wrapping, TXT and JSON paths are preserved.

Build only with `python tools/build_qa27_candidate.py`; set NYX_CLANG and
NYX_LLD_LINK to verified local LLVM binaries. This entry point never dispatches
regression suites. The old full builder is historical infrastructure and is
not the QA27 gate scheduler.

Native Windows PowerShell5.1 focused F-024 must pass FIRST, using an existing
permitted execution route and the exact extracted QA27 Portable bytes. Run
Test-QA27PdfExportBlankLines.ps1 followed by independent PDF parsing/rendering.
Only then run applicable missing non-DPI gates. No QA-created execution Bypass,
script inlining, re-signing, trust/policy changes or launcher trampoline.

Do not alter current stable scale. No DPI/scaling tests or recovery. Archived
historical matrix remains83/132; remaining49 are
`WAIVED_BY_OWNER_DPI_SCOPE_20261019`, not PASS/FAIL or release blockers. Historical
DPI instructions elsewhere are superseded by Issue15 policy comment6277826979.

QA26's328PASS/1FAIL does not carry into QA27. Unrelated completed tests are not
repeated. Blocked lifecycle/migration require the approved untouched compatible
nativePS5.1 baseline. Issue16 security review remains separate and unapproved.
Stop on the first genuine product failure and preserve exact evidence.

Independent QA owns final PASS/HOLD/FAIL. Release authorization is false.
