# QA27: F-024 PDF separator-line correction

Base source: `0303a78a06f67252c86634cd73f1e4bda32dd3cc`.
Branch: `eng/f024-pdf-export-empty-lines`.
Build: `2026.10.19-eng-qa27`. Harness: `QA27-F024-PS51-27`.

QA26 artifacts, source, failure evidence and branch remain immutable. The new
PDF-writing contract accepts strings including empty strings and an empty
collection. Empty strings remain real lines, including consecutive lines and
lines at page boundaries. An empty collection retains the existing one-page
fallback. Null collections, null elements and non-string elements are rejected
before output. Positive wrapping width is required. Normal escaping, printable
ASCII conversion, wrapping, line advance, pagination and other export writers
are unchanged. Intentional whitespace is never filtered away.

Run the focused gate FIRST against the extracted immutable QA27 Portable app
using an already permitted native Windows PowerShell 5.1 Desktop execution
route. Do not change policy, sign runtime copies, inline blocked scripts, or
use the product launcher as a harness trampoline. A fresh evidence directory
is mandatory; an existing run is never overwritten/repeated to repair proof.

`tests/powershell/Test-QA27PdfExportBlankLines.ps1` tests ordinary lines, one
blank, consecutive blanks, a singleton blank, empty collection, escaping,
whitespace, wrapping, page-boundary spacing, null/invalid input, representative
preserved Full scan-to-PDF, TXT and JSON. It verifies success, exact scan hash,
files/nonzero bytes, PDF header/trailer and text commands. It stops at the
first unexpected assertion/exception and preserves its raw result and outputs.
The supplied scan must be the preserved Full raw with SHA256
`9EBD0A3DD3933AB3161AE1629E9E010A0805C4A177CC440E560BB1B67A4295DE`.
It does not start a scan or overwrite existing scan/config/history data.

Then `tools/verify_f024_pdfs.py` opens those exact PDFs with an independent PDF
reader, validates extractable content and confirms blank-line spacing of 26
and 39 points. Render and visually inspect the focused PDFs before declaring
the focused gate green. No other native or source regression gate may precede
this focused gate. Pending/blocked execution is not PASS.

Build artifacts with `tools/build_qa27_candidate.py`, which uses the existing
deterministic compiler/package functions without dispatching regression suites.
Set NYX_CLANG and NYX_LLD_LINK to existing verified build tools. Source packages
include all source needed to reproduce Setup/Portable, the focused regression
and the fixed QA2 fixtures; they do not include historical evidence archives.

Issue #15 owner policy comment 6277826979 supersedes old DPI acceptance text:
historical matrix stays 83/132. Remaining 49 cells are
`WAIVED_BY_OWNER_DPI_SCOPE_20261019`, not PASS, FAIL or release blockers. No
scaling/DPI transitions, matrices or missing-DPI evidence recovery. Keep stable
scale. Unrelated completed tests are not repeated; QA26 credit is not copied
into QA27. Lifecycle/migration remain blocked pending the approved untouched
compatible native PS5.1 baseline. Issue #16 security review stays separate.

Independent QA owns final PASS/HOLD/FAIL. This source correction grants no
release authorization or security approval.
