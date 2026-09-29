# QA25 independent deep audit and finite acceptance contract

Review date: 2026-09-29. Engineering -> Independent QA only.

**Disposition: HOLD / native acceptance pending. No new QA25 native failure is classified by this source audit. No product bytes changed.**

This record supersedes the stale instruction to build QA25: QA25 is already published. Continue the exact candidate, not a reconstructed approximation. Findings A01-A08 below distinguish source/test defects or risks from reproduced installed failures. They are not speculative new F-numbers.

## 1. Frozen identity and evidence provenance

- Product source: `f55c0d3bda6a99a20d218a2a390f217963a0d9be`.
- Engineering branch: `eng/f022-apps-dpi-column-readability`.
- Evidence HEAD at review start: `b2f3a9c4251901b58500a4f0ed7653b7bdbc382c`.
- Build: `2026.09.28-eng-qa25`.
- Product harness: `QA25-F022-PS51-25`.
- Candidate tag: `qa25-f022-candidate-20260928`; its actual Git ref was read and resolves directly to the source commit above.
- Authoritative issue: #14 / F-022.

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| Nyx_PC_Checkup_1.0.0_Setup.exe | 559104 | 5F5C1C294F23487DE1B4325173DC72C89950A2AAA96EBB1AC3F80B6CDE788112 |
| Nyx_PC_Checkup_1.0.0_Portable.zip | 220566 | B38A40D40CFFE86E30F1EA8E88D21295D14B1DD792D60A27962A22783E63D19C |
| Nyx_PC_Checkup_1.0.0_Source.zip | 794752 | A4ED460A880BA04A289F504312BF7A1B8D0F3C1A5956DE46E19AFC837CF7049C |

Declared canonical source-tree SHA-256: `25D71479533E639EFC8A82ED2B93FDE3A6D47B632BB8EFBBEDAE819F9C3B0A60`.

These archive values were read from `engineering/qa25/source-regression/QA25_CANDIDATE.json` at the evidence commit, not independently downloaded/recomputed in this audit. Before native execution, verify the actual archives and the established source-tree manifest. Git commit SHA, source-tree SHA-256 and ZIP SHA-256 are different identities.

Engineering reports 220/220 post-build Python, 2/2 lint, 1328/1328 real Apps source-geometry assertions, and 125/125 deferred-page callback assertions. These are not native DPI acceptance or 1328 user journeys. Source geometry emulates scales. Some shared/callback output retains QA24 labels; preserve the originals and establish module/test hashes or rerun the small ambiguous diagnostic separately. Do not edit labels to manufacture new execution.

The connected source, current issue, tag and candidate record were inspected. The uploaded QA23 source was extracted for broader unchanged-module review and checked against the QA23-to-QA25 Git comparison. No Windows VM, WinForms application, PowerShell 5.1 runtime or installer was executed by this audit. Local Python self-tests concern the evidence checker only. No overall completion percentage is calculated.

## 2. F-022 root cause and the existing correction

The Engineering baseline reproduced QA24 Reported size widths 140/98/57/20 at 100/125/150/200 percent geometry. `Set-NyxDeviceGeometry` assigned column widths sequentially while Fill sizing was active. Earlier assignments redistributed subsequent widths and FillWeight; low default minima did not protect readable content.

QA25 Apps uses sizing None, both scrollbars, and logical widths/minima:

| Scale | Application | Publisher | Version | Install date | Reported size |
|---|---:|---:|---:|---:|---:|
| 100% | 240 | 200 | 150 | 130 | 150 |
| 125% | 300 | 250 | 188 | 162 | 188 |
| 150% | 360 | 300 | 225 | 195 | 225 |
| 200% | 480 | 400 | 300 | 260 | 300 |

These are policy expectations, not new native measurements. They use nearest-integer midpoint-to-even rounding, matching the frozen test; 162.5 becomes 162. Do not invent a failure by checking against ceiling. QA25 also captures a column's original Width before raising MinimumWidth, avoiding a separate minimum-clamping/double-scaling interaction. Filtering rebuilds rows rather than discarding the column policy.

At 200%, the total column width is 1740 pixels, so internal horizontal scrolling is expected. A practical column width and actual focused-cell visibility are separate predicates. Validate both. Bounded essential fields must be readable; arbitrary long application names need a keyboard-accessible full-value route, not an impossible requirement that every long string fit one screen.

## 3. Prioritized source risks and test gaps

### A01 — Remaining Fill-mode pages still need the same mechanism tested

Apps alone changed to None. Shared New-NyxGrid still defaults to Fill. Results/category, Storage folder/largest-file and Cleanup grids remain consumers. The shared scaling loop still mutates columns sequentially. Capturing each column before its own MinimumWidth assignment is not the same as snapshotting every column before any earlier mutation. Deliberate FillWeights do not prove immunity.

This is a confirmed source exposure, not a newly reproduced QA25 native failure. Construct each real page with representative data at 150%/200%, capture all Width/MinimumWidth/FillWeight values before and after scaling, focus endpoints, resize and page recreation. Prioritize Cleanup consequence/checkbox columns and result Status/Finding. Do not flip shared sizing globally without a demonstrated requirement and regression evidence. If a new candidate is needed, consider per-grid explicit policies or a truly atomic Fill policy preserving baseline weights. Do not patch frozen QA25 speculatively.

### A02 — Shared geometry oracle can pass a one-pixel sliver

`Test-QA23GridFocusVisibility.ps1` accepts `intersection.Width -gt 0` and begins with an already clipped rectangle. Thus a one-pixel horizontal intersection can pass. It also uses a synthetic None-mode grid. It is not a readable-column oracle for all real pages.

The Apps-specific QA25 test is stronger: it compares full and clipped cell sizes, practical minimums, and Size text. But it is emulated-scale source geometry with reflected key calls, not desktop-shortcut/native-DPI evidence. Its Light fixture does not cover every theme or runtime DPI transition.

Add a supplemental evidence-only observer under engineering/qa25, not edits to frozen product tests. Compute visibility from the UNCLIPPED cell through the grid's data viewport, every clipping ancestor, and the active work area in one physical-pixel coordinate space. Record focus, settled layout, column width/minimum, inherited font/style and essential text measurement. Independently reject: one visible pixel; fully visible 20-pixel column; clipped row; wrong DPI; unfocused/disposed control; stale/unsettled record. Width greater than zero is not enough. A two-pixel border tolerance must never substitute for meaningful content visibility.

### A03 — Worker exit is not UI completion

`Start-NyxScan` refuses a start only while the stored worker is alive. Once it exits, new scan paths/process can overwrite the old state before `Update-NyxScanProgress` consumes the old output and performs cleanup on its timer. Previous immediate-transition tests waited for cleanup, leaving this earlier interval untested.

Probe Quick->Full and Full->Quick in three phases: worker active; worker exited but UI completion pending; cleanup complete. Record old/new scan IDs and output paths, worker exit, completion entry/exit, cleanup, next dispatch and next worker start. The UI must reject/queue/finalize safely, without orphaning old output. This is a source-derived ordering risk, not a confirmed native failure. Label deterministic installed-runtime integration separately from native shortcut testing; do not modify product functions or fabricated result JSON to obtain a pass.

### A04 — Valid outer scan schema does not validate nested Details

`Convert-NyxScanResult` validates common fields and passes optional Details through. Storage reads Details.Folders/LargestFiles; Cleanup reads Details.Candidates; Apps reads properties of detail elements. Test valid outer schemas with missing/null/scalar/empty/partially malformed nested content, including legitimate Unknown/partial results.

Use isolated persisted fixtures through the actual load path. Required outcomes are explicit rejection with a diagnostic, or safe honest unavailable/partial rendering. Never invent Good results or authorize destructive actions from unvalidated nested content. This is a source risk pending runtime proof. Do not change QA25 solely because it is listed.

### A05 — Presentation failure may bypass completion cleanup

`Update-NyxScanProgress` stops its timer, reads output, renders the page and displays a notification before clearing artifacts and scan state. The broad outer catch logs a warning. A rendering exception could skip cleanup. Probe this in isolated diagnostic integration, including modal dismissal/close/navigation ordering, and retain the exact injection method. No such QA25 native failure is claimed here.

### A06 — Navigation is not keyboard activation

The inspected common result-grid detail binding is CellDoubleClick. Verify that a keyboard-only user can actually open the selected result's details, dismiss the dialog and regain visible focus. Perform the equivalent check for Storage file actions and full values. Do not count arrow-key selection as proof of action accessibility; do not classify a defect before checking any alternate route.

### A07 — Lifetime and DPI transitions need their own cases

Test repeated page recreation, pending per-grid timer disposal, filter/current-cell/selection reset, resize, same-scale layout twice, and 100->125->150->200->100 transitions where supported. Separate page constructors per scale do not establish transition stability. Check widths and minima for drift, not only the final Size column.

Do not mechanically replace every local callback: callbacks invoked while a containing ShowDialog/Application.Run remains active have a different lifetime from callbacks after a page-construction function returns. Audit actual lifetime and explicit state, not variable-name regex alone.

### A08 — Evidence identity and measurement gaps are separate from product defects

49/60/61-file reports are not interchangeable without reconciling manifest scope and generated extras. Requested custom scaling before sign-out is not proof of applied scaling after login. DeviceDpi=96 alone is not reliable in the observed host. Capture effective native/window-DC DPI, observer awareness, actual resolution/work area, selected theme AND resolved theme. A screenshot inside a VM host frame is not automatically an unscaled guest raster. Do not compare unrelated coordinate spaces.

No new numbered blocker is created by A01-A08. Keep risks visible until tested, rejected with evidence, or formally classified.

## 4. All-page acceptance surface

| Page | Required states and behavior |
|---|---|
| Home | No scan, completed and partial/Unknown data; truthful summaries; every card, action, status and footer readable/reachable. |
| Checkup | Quick/Full/cancel; zero/one/many rows; all result columns; keyboard detail activation and return focus. |
| Storage | Category results, measured-folder subgrid AND largest-file subgrid; long paths; missing details; safe file-location action. |
| Startup | Fresh/repeated Refresh; after Quick/Full/cancel; fixture Disable/Re-enable with exact restore; all-users read-only; valid/missing location; all rows/columns keyboard-visible. |
| Security | Zero/one/many/Unknown results; readable status/evidence; official Windows redirect without modifying protection. |
| Updates | Local update indicators and uncertainty; official Windows redirect; distinct from Nyx application updates. |
| Backup | Historical one-result Count case; zero/many/Unknown data; no invented backup assurance. |
| System | Mixed System/Battery/Drive/Performance/Network results, absent capabilities, details and keyboard action. |
| Apps | Search first character, names/publishers, literal punctuation, no match, clear, populated/empty/partial data; selection/folder actions; endpoints; every column and Size readability. |
| Cleanup | Empty/populated preview; checkbox edits and summary; exact selection/confirmation; Cancel changes nothing; only disposable fixture actions; readable consequences. |
| Settings | FollowWindows/Dark/Light persistence; notifications and automatic/manual update checks; data/log buttons, no network upload, weekly promise stays removed. |

F-008 is still the established 3 themes x 4 scales x 11 pages = 132 cells, not 132 screenshots. Track the subcases inside each cell rather than quietly declaring every new fixture a new release gate. Use 1366x768 for the protocol's constrained 150%/200% cases. All page-open-only observations are PARTIAL until the full checklist is satisfied. Long free text may use accessible details; essential status/size/action text may not collapse to a sliver.

## 5. Lifecycle, actions, privacy and packaging

Retain Standard/Elevated smoke, privilege/rollback, migration, installer lifecycle, F-011 installed visible launch/singleton, F-012 theme/settings, F-010 cancellation/relaunch and malformed state, plus the project's remaining required privacy/safety gates. Historical successes on earlier product bytes guide scope but do not become successor PASS automatically.

For scans, distinguish honest unsupported-capability Unknown from an internal exception hidden inside a schema-valid result. Validate every authoritative run's common and relevant nested contracts, cancellation truth, mode/timestamps, WorkerError, and live worker/artifact cleanup. Preserve genuine Quick cancellation and both immediate transition directions. Reader counts are reads, not additional scans. Shared readers need compatible access and must not themselves falsify the failure class.

For Startup and Cleanup, use unique disposable guest fixtures. Do not disable the user's real OneDrive or empty a real Recycle Bin merely to obtain evidence. Capture exact before/after registry value bytes/types, restore successful changes, and record residual artifacts. Current-user actions need explicit confirmation; all-users entries remain read-only. Scanning never authorizes changes. Verify selected item, displayed consequence and executed identity agree; stale or changed paths must fail safely.

For reports/privacy, test secret-bearing synthetic values, usernames, email/IP forms and nested strings through actual preview/export paths. No real credentials are needed. Check that cancellation creates no output and that failures are reported honestly. A fixture marker not leaking is useful evidence, not proof of perfect redaction. Optional app update checks fetch the fixed allowed manifest, not inventory/reports; preserve disabled/manual semantics, rate limiting and destination validation. Removal of the weekly wording does not remove update checks or secretly alter their schedule.

Final staging must be allowlisted. Intentionally shipped PowerShell runtime scripts are runtime, not disposable developer source. Exclude tests, engineering evidence, debug caches and secrets. Verify installed-versus-portable expected file sets plus documented installer-generated metadata. If signing/repackaging changes final distribution bytes, evaluate those exact bytes; self-signing is not equivalent to public certificate trust. Keep review evidence private and product publication separate.

## 6. Evidence contract and finite execution order

A run record needs source/build/archive identity, harness version/hash, session ID, OS/PS5.1/runtime architecture, applied DPI method, observer awareness, physical resolution/work area, selected/resolved theme, exact action sequence, expected/observed outcome, raw evidence references/hashes, and PASS/FAIL/NOT_RUN/PARTIAL/BLOCKED_HARNESS. Link artifacts rather than nesting historical ZIPs. Preserve original report labels and line endings; store normalized adapters separately. A corrected collector does not correct the product.

Correct the pending evidence-output path only in harness space, using a new normal writable evidence directory outside the application workspace. Do not bypass UAC/security prompts. Preserve the old guest state. Export consistent guest-side files and hash on both sides. Live cleanup must be captured before shutdown; empty post-shutdown temp is not sufficient.

1. **Identity/harness:** verify current issue/tag/source and all three existing archives; reconcile installed manifests; correct only the evidence path; no build.
2. **High-yield preflight:** exact F-022 Apps 200%/1366x768 first; strengthened oracle plus remaining real Fill grids; bounded A03-A06 fixture diagnostics. Stop acceptance at the first genuine frozen-product failure and preserve it for Independent QA.
3. **Focused native gates:** F-022 scales, affected F-021 Apps/Cleanup callbacks, F-020 cross-page focus, F-015 Startup functional/DPI. Same-candidate evidence can satisfy overlapping predicates when context is explicit, without double-counting runs.
4. **Complete F-008:** all 132 cells, subgrids and keyboard actions. Reverify environment after sign-in/DPI changes. Resume valid same-byte evidence after credit interruptions; do not reset the campaign merely because the chat stopped.
5. **Final suites/review:** all established remaining Standard/Elevated/lifecycle/privacy gates, one master index, exact unmet gates, Independent QA verdict. No public release approval is issued here.

If only evidence/harness work changes, do not rebuild QA25 or make QA26. If a real product change becomes necessary, preserve QA25, obtain defect classification, create a distinct successor and execute its justified regression plan. Source suspicions alone do not authorize rewriting a frozen candidate. Draft unit-test iteration before a future candidate is frozen is normal Engineering work, not a reason to stop for a new chat after every failed draft assertion. This does not authorize modifying frozen QA25.

## 7. Evidence guard and scope

The accompanying standard-library Python tool verifies existing QA25 archive hashes when supplied, validates 132-cell coverage/evidence references, rejects unsafe paths and duplicate JSON keys, and checks supplied focused-cell geometry. It is not a Windows runner, screenshot judge or release certification system. Its local tests concern this guard only. No native QA25 test was executed during this audit.

```text
python -m unittest discover -s engineering/qa25/deep-audit-20260929/tests -v
python engineering/qa25/deep-audit-20260929/tools/qa25_evidence_guard.py verify-artifacts PATH_TO_EXISTING_QA25_FILES
python engineering/qa25/deep-audit-20260929/tools/qa25_evidence_guard.py init-matrix NEW_MATRIX.json
python engineering/qa25/deep-audit-20260929/tools/qa25_evidence_guard.py geometry NATIVE_GEOMETRY.json
python engineering/qa25/deep-audit-20260929/tools/qa25_evidence_guard.py matrix MATRIX.json --evidence-root EVIDENCE_DIR --require-complete
```

Exit 2: invalid/failed supplied check. Matrix exit 3: valid but incomplete evidence, not a product defect. Zero exit is scope-limited validation, not release approval. Archive checking does not recompute canonical source-tree SHA-256. Native observer output must include all clipping rectangles and accurate data; the tool cannot authenticate observations or prove that a screenshot depicts a stated action. Unit fixtures are explicitly fictional and never exported as native evidence.

## Source anchors

All product paths below are pinned to source `f55c0d3bda6a99a20d218a2a390f217963a0d9be` unless stated otherwise.

- Current return: Issue #14 comment 5880682423.
- Candidate identity: `engineering/qa25/source-regression/QA25_CANDIDATE.json` at `b2f3a9c4251901b58500a4f0ed7653b7bdbc382c`.
- Root cause and correction: `product/docs/QA25_F022_COLUMN_READABILITY.md`.
- Geometry/focus/shared Fill source: `product/src/app/ui/Controls.psm1`.
- Apps/Cleanup state, column policy, shared grids, scan completion: `product/src/app/ui/MainWindow.psm1`.
- Outer/nested result contract: `product/src/app/core/CheckupEngine.psm1`.
- Weak shared oracle: `product/tests/powershell/Test-QA23GridFocusVisibility.ps1`.
- Stronger Apps-only source oracle: `product/tests/powershell/Test-QA25AppsColumnReadability.ps1`.
- Broader unchanged-module provenance: QA23 source `109a9f8d73ebc68bbcb678f2c4c356d80cad9af5` compared to QA25; actions, core Paths/Privacy, reports, updates, ActionWorker/ScanWorker, native launcher and build_release.py reviewed as contract surfaces, not certified exhaustively.
- Microsoft Fill-mode documentation: https://learn.microsoft.com/en-us/dotnet/desktop/winforms/controls/column-fill-mode-in-the-windows-forms-datagridview-control
- Microsoft MinimumWidth documentation: https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.datagridviewcolumn.minimumwidth?view=netframework-4.8.1
- Microsoft GetDpiForWindow documentation: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getdpiforwindow
