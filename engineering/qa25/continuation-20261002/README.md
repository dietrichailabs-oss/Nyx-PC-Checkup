# QA25 native continuation: stopped for Independent QA review

Engineering evidence, not Independent QA approval. QA25 remains frozen.

## Exact candidate

- Branch: eng/f022-apps-dpi-column-readability
- Frozen product source: f55c0d3bda6a99a20d218a2a390f217963a0d9be
- Build: 2026.09.28-eng-qa25
- Product harness: QA25-F022-PS51-25
- Candidate tag: qa25-f022-candidate-20260928
- Source tree: 25D71479533E639EFC8A82ED2B93FDE3A6D47B632BB8EFBBEDAE819F9C3B0A60

Setup, Portable and Source are referenced through the existing immutable candidate release. This evidence transport does not rebuild or repackage that candidate.

## Stop condition / A06 bounded native observation

In the installed application's Checkup results grid, Enter moved selection rather than opening details. Space and Shift+F10 opened no dialog. Double-clicking the same System-drive free space result opened its details dialog. Screenshots preserve negative keyboard observations and the positive mouse control.

This is a reproducible keyboard-activation gap for the tested routes, submitted for Independent QA classification. It is not a claim that every possible alternate shortcut has been exhausted. No new numbered defect or product correction is assigned here. Native acceptance stopped; unexecuted gates have not been promoted to PASS.

Reproduction:

1. Launch the installed frozen QA25 and open Checkup with existing real results.
2. Scroll to the grid and focus a result cell.
3. Press Enter: selection moves to the next row, no details dialog.
4. Press Space and Shift+F10: no details dialog/context route observed.
5. Double-click the selected System-drive free space row: details dialog opens.

The host basic-session VM console scales its screenshots. These images are action evidence, not physical-pixel geometry/DPI proof. The non-elevated guest was provisioned by the collector's native PowerShell 5.1 checks; consult raw guest records for identity/runtime evidence. Do not infer applied DPI, actual guest resolution, or resolved theme from requested settings or host-frame pixels.

## Completed native observations (not complete gates)

Apps populated with real inventory. Search to grid Tab, Ctrl+End, Ctrl+Home, End, reverse Tab from first cell, native typed `edge` filtering, filtered endpoint navigation, clearing, and Home/Apps recreation were exercised. Endpoint values and focus were visible. General text injection did not pass through the basic VM session; ordinary key input did. This transport problem is not a product finding.

F-022 is PARTIAL: actual physical cell bounds, clipping ancestors and effective DPI remain unproven. No F-008 cell is marked PASS on page-opening observations alone.

## Identity checks completed

All three archive sizes/hashes match the frozen candidate. The Source ZIP's canonical manifest matches all 142 source records and the expected source-tree SHA-256. The installed inventory contains 61 files: all 60 Portable files match size/hash, including all 49 runtime-required files; the sole extra is `install-state.json`, documented by the exact frozen InstallWorker generation site. Its contents were not collected, so its schema is not separately asserted. Setup exited 0. Guest collector reports Windows PowerShell 5.1.26100.7920, Windows build 26200 and disposable user Nyx. The live collector observed the app process and then three empty process samples after closure. This proves that observation only, not worker/temp/handle cleanup.

The evidence guard ran 43/43 self-tests successfully during this continuation. Its archive checker also passed. These are not native application gate counts. See IDENTITY_RECONCILIATION.json and INSTALLER_GENERATED_METADATA_PROVENANCE.json.

The real result data already present at session start was reused for UI navigation. No new Quick/Full scan completion is claimed. Historical entries within collected logs/action history remain raw and are not counted as QA25 passes.

## Outstanding

- F-022 complete native geometry / resize / manual scrolling at required scales.
- A01 real Fill grids; A03 worker/UI transition ordering; A04 nested malformed Details; A05 presentation cleanup; A07 transition stability; remaining A08 environment evidence.
- Complete F-021, F-020 and F-015 focused acceptance.
- F-008: 132 cells outstanding; partial observations do not count as passed cells.
- QA25 Standard/Smoke, migration, privilege/rollback, installer lifecycle, F-011, F-012, F-010, F-016, Elevated and remaining privacy/safety gates.

Historical or source-only successes are not newly executed native gate counts. The audit guard's tests are guard tests only.

## Evidence

See raw screenshots/records, guest session logs, installed inventory, identity verification, acceptance matrix and SHA256SUMS in this directory/transport. Offline inventory is not live pre-shutdown cleanup proof. The VM is left off after collection to preserve this session and avoid its startup installer running again.

Independent QA owns PASS / HOLD / FAIL and the next disposition. No public release approval is issued.
