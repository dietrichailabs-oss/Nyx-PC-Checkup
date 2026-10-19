# QA27 F-024 Engineering handoff — native focused execution blocked

Source commit: [`ee357ca33dbb87653924c6def90ff29a38898fdb`](https://github.com/dietrichailabs-oss/Nyx-PC-Checkup/commit/ee357ca33dbb87653924c6def90ff29a38898fdb)  
Base: `0303a78a06f67252c86634cd73f1e4bda32dd3cc`  
Branch: `eng/f024-pdf-export-empty-lines`  
Build: `2026.10.19-eng-qa27`  
Harness: `QA27-F024-PS51-27`  
Source tree SHA256: `103D15B084ED4CE02D314D89C7B2D92599122D0C2936113A1EF585355EC240D6` (149 records, excluding identity file itself).

## Change and regression coverage

`PdfWriter.psm1` accepts legitimate empty strings and empty collections. Blank
rows retain line advances, including consecutive and page-boundary blanks.
An empty collection retains the existing fallback page. Null collections/null
elements/non-string elements are rejected before writing. Positive wrapping
width is validated. Escaping, printable ASCII handling, wrapping, rendering
operators, TXT and JSON writers are unchanged. Version/harness identities and
build documentation were updated for the separate successor.

The exact native focused script covers ordinary/single/consecutive/only-blank
and empty input, escaping/wrapping/whitespace, pagination, invalid/null inputs,
actual preserved Full scan-to-PDF success/file bytes/header, and TXT/JSON. The
independent parser checks readable content, valid PDF structure and 26/39pt
blank-line spacing. These are **prepared tests, not passed tests**.

## Execution result and gate ordering

Build-only process exited0. Focused source parses under native PS5.1 with zero
diagnostics; this is syntax evidence only. The exact focused native launch was
attempted FIRST with `-NoLogo -NoProfile -NonInteractive -File`, without any
execution-policy argument. Windows rejected it under Restricted before the
script body; no output directory or PDF exists. Raw stdout/stderr and command
receipt are preserved. **QA27 regression score0PASS/0FAIL; native F-024 BLOCKED.**
No independent PDF parsing/rendering, unrelated Python suites, native smoke,
UI, F010/F016, privilege, lifecycle or migration gates were dispatched. Do not
infer success/file readability from the code correction or artifact build.
Stop on the first genuine product failure once an approved route is available.

## Immutable artifacts

| Artifact | Bytes | SHA256 |
|---|---:|---|
| [setup](artifacts/Nyx_PC_Checkup_1.0.0_Setup.exe) | 553984 | `8251F288E069F9B94DC98FF6B87E2C70326EAE8888FFA41B64E90C4527165EE8` |
| [portable](artifacts/Nyx_PC_Checkup_1.0.0_Portable.zip) | 218651 | `C59D1726E43C3EDE8E0AAC6014B067207102CBB51F9E2308265E597FCA6AB610` |
| [source](artifacts/Nyx_PC_Checkup_1.0.0_Source.zip) | 806768 | `B0F7B77140E6B578738E17DE69836E100A18E0201040B53906D2A1EF10E393A5` |

Artifacts are stored on this private branch as small immutable Git blobs so
Independent QA can obtain exact bytes without this guest's filesystem. This is
an Engineering candidate/handoff, not a product release or approval. GitHub
binary file views have a Download raw file action. Source commit + candidate
hashes remain authoritative if the branch later advances with evidence.

## Prerequisites and preserved boundaries

An existing approved nativePS5.1 execution environment must permit these exact
unsigned modules/scripts without policy/trust/security changes. This AppSetup
guest is Restricted and is not the approved untouched lifecycle/migration
baseline. The recorded MARK host is also Restricted. An authenticated host
connection alone does not qualify a compatible baseline. Do not improvise a
workaround, install QA27 over the preserved QA26 installation, re-sign runtime
copies, inline blocked scripts, use a different PowerShell engine for credit,
or run a harness through the product launcher.

Use the extracted immutable Portable app as AppRoot. Read
`product/docs/QA27_F024_PDF_EXPORT.md` and the focused runner parameters. Supply
the included exact preserved Full raw (SHA256
9EBD0A3DD3933AB3161AE1629E9E010A0805C4A177CC440E560BB1B67A4295DE)
and a fresh evidence directory on that approved environment. Verify payload
hashes and identity before execution. Follow native success with independent
PDF parsing and visual rendering before opening subsequent applicable gates.
Do not repeat unrelated completed or executed-unqualified cases. A prior
policy denial ran zero test bodies; no failed product test is being retried.

All original QA26 bytes, PDF failure, unqualified attempts and old branch remain
preserved. QA26's reconciled328EngineeringPASS/1FAIL is historical and contributes
zero QA27 credit. Current installed60 frozen files, preserved scan/config/history
and previous evidence-manifest files were reverified. Original Nyx VM was not
accessed; no VM lifecycle operations were used. The exact published source
is based on all146 verified frozen Git product blobs. CRLF archive text was
normalized only to match existing Git blobs; binary bytes were not normalized.

Issue15 owner policy comment6277826979 archives the matrix at83/132 and classifies
remaining49 as WAIVED_BY_OWNER_DPI_SCOPE_20261019. No DPI/scaling/layout matrix,
transitions, missing-DPI evidence recovery or comprehensive DPI claim. Current
stable scale untouched. Those waived cells are not PASS/FAIL or release blockers.
Lifecycle/migration remain BLOCKED_ENVIRONMENT_LEGACY_PS51_IMPORT_BASELINE.
Issue16 launcher-security review remains OPEN/NOT APPROVED and separate.

Policy: https://github.com/dietrichailabs-oss/Nyx-PC-Checkup/issues/15#issuecomment-6277826979  
Finding: https://github.com/dietrichailabs-oss/Nyx-PC-Checkup/issues/18  
Preserved QA26 handoff: https://github.com/dietrichailabs-oss/Nyx-PC-Checkup/blob/e20ba656882c01c9c4262838f4a76714d995bc05/engineering/qa26/handoffs/QA26_ENGINEERING_EVIDENCE_20261019_212515_R1/README.md

Independent QA alone owns final PASS/HOLD/FAIL. No release/security approval.
