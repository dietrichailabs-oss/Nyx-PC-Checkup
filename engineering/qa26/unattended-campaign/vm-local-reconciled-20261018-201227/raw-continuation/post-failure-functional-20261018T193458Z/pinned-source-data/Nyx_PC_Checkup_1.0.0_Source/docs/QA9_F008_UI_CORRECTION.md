# QA9-F-008 — Final UI / DPI Responsiveness Correction

## Prior QA finding

Independent QA returned **FAIL — RETURN TO ENGINEERING** for QA9 because the shipped UI did not satisfy constrained high-DPI visual acceptance. At 150% scaling on a 1366×768-class viewport, required global and page-specific controls/labels were clipped or initially outside the usable viewport. Keyboard focus could also reach an offscreen Export report control.

Exact prior QA evidence:

- File: `Nyx_PC_Checkup_1.0.0_Independent_QA9_FINAL_UI_FAIL_Master_Handoff(1).zip`
- Size: `85,017,549 bytes`
- SHA-256: `33B355C6F426321D3B5AAE764EFD8E3DC09006E2643E751E8DAD7FEB3993BA38`

Exact reviewed QA9 Engineering handoff:

- File: `Nyx_PC_Checkup_1.0.0_Engineering_QA9_Migration_Harness_WH006_Corrected_Master_Handoff(1).zip`
- Size: `84,115,464 bytes`
- SHA-256: `5EFFAF04D5C7041E37176D0887A64567570E5B45FE33D15474778C452214E31E`

Frozen QA9 product hashes:

- Setup: `AB09FCA0574AC6D84A7289B271892EBE4DAF1AD1E0AA4ECBF0670012F070B5EA`
- Portable: `8EE1142084C121B9106EED9387C70DC3D06BADCE737F38A8B2847671AEC7FA7C`
- Source: `97EBF6A219CC2DEDC9BE975C58C96E5988241D98F5692130BCDE543229F11C82`

## QA9 native baseline preserved as regression boundary

Before final visual acceptance, QA9 recorded:

- Smoke: `97/97 PASS`
- Standard privilege/rollback: `12/12 PASS`
- Exact QA2 migration: `244/244 PASS`
- Standard installer lifecycle: `44/44 PASS`
- Elevated privilege/rollback: `14/14 PASS`
- Elevated installer lifecycle: `50/50 PASS`

## QA10 engineering correction

`src/app/ui/MainWindow.psm1` now uses DPI-aware initial sizing constrained to the primary-screen working area, a contractible page width, docked header/footer action containers, docked version display, explicit page scroll extents, and focus-driven scroll-into-view.

The Startup page places Refresh, Disable selected, Re-enable selected, and Open file location before its grid. The Apps page places Open Installed Apps, Run Full Check, and Open selected folder before its grid. Cleanup is vertically compacted so its review action appears earlier. Settings uses wider, wrapped controls and a defined scroll extent.

`src/app/ui/Controls.psm1` disables label/button auto-ellipsis, enables compatible text rendering for wrapping, and enables grid cell tooltips/automatic header sizing. Startup uses horizontal/vertical grid scrolling with explicit widths for all visible columns.

## Engineering boundary

The Linux Engineering environment cannot render WinForms under Windows display-scaling semantics. Static/layout regressions prove the correction is wired into shipped source, but they do not substitute for native visual inspection. Independent QA must complete the exact final UI matrix in `QA_TEST_PLAN.md` on QA11 bytes before PASS.
