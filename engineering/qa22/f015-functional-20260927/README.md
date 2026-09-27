# QA22 F-015 functional continuation: HOLD / INCOMPLETE

Frozen source: 958813267b6f69466770701816146de234cf1388
Build: 2026.09.27-eng-qa22
Product harness: QA22-F019-PS51-22
Evidence-only fixture: QA22-F015-FIXTURE-1

No rebuild, successor, or candidate repackaging. No Independent QA approval is asserted.

## Native UI observations

13 focused functional observations now positive at custom 100% / 1366x768:
fresh Refresh; Refresh x3; away/back Refresh; current-user Disable; disabled state
survives Refresh; Re-enable; restored state survives Refresh; all-users actions
remain inert/read-only; valid Open file location; unavailable Open file location;
Refresh after completed Quick; Refresh after completed Full; Refresh after genuine
Full cancellation. No unhandled exception was observed.

The observations JSON in screenshots predates the missing-target check. Its
pending missing-target entry is superseded by OPEN_MISSING_TARGET.png and the
fixture records in this checkpoint. DPI and full matrix work remain pending.

OneDrive disable/restore records in ACTION_HISTORY.jsonl are successful, linked
rollback operations. The temporary missing-target fixture is removed after UI
close. STARTUP_BEFORE.json and STARTUP_RESTORED.json match. Before/after installed
inventory: 61 files, 0 hash differences. This is a session immutability comparison,
not a substitute for the candidate archive identities or previous portable match.

## Additional scan evidence

Quick: 2026-09-27T20:28:05.3797393Z to 20:28:22.4601292Z, 15 results, not cancelled.
Full: 2026-09-27T20:29:04.5968452Z to 20:29:22.7786721Z, 21 results, not cancelled.
Cancelled Full: 2026-09-27T20:30:14.729594Z to 20:30:22.599636Z, 11 partial results.
All 3 observer validations pass, ReadOnly=true, no WorkerError. The first observer
capture at 16:15:07 local is a prior baseline, NOT a fourth new run. This session
adds 2,701 concurrent shared progress reads (1,128 + 1,075 + 498).
Live pre-shutdown records at 16:33:50-52 local show zero workers, zero scan artifacts,
and disposed observer handles while GuestRunning=true. Offline copy is not used
as cleanup proof.

## Remaining acceptance

F-016 timing completion remains recorded in commit
8d1134193e54e72219ed981d8e017a19c6e37660 and asset
QA22_F016_TIMING_PASS_20260927_161446.zip.

F-015 full DPI coverage is NOT complete. Custom 100% was read from Windows Settings;
the disabled display dropdown's 125% label is not counted as active scaling.
Custom 200% was requested, then the guest restarted. At capture the guest is at its
lock screen awaiting user sign-in. No 200% app result is claimed yet.

F-008 complete acceptance cells: 0/132 in this continuation. Page opening alone
is not counted. Remaining acceptance suites are not claimed as completed.
No new genuine product defect has been established.
