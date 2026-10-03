# QA26 installed Quick re-render evidence, 125%

Evidence only; frozen product remains unchanged. Build 2026.10.02-eng-qa26; harness QA26-F023-PS51-26; source 0303a78a06f67252c86634cd73f1e4bda32dd3cc.

Actual installed Quick scan: 2026-10-03T04:23:26.6146932Z through 2026-10-03T04:23:44.1075960Z. 15 authoritative results; ReadOnly=true; Cancelled=false; no WorkerError. Corrected result validation 10/10. Original 9/10 report retained: validator incorrectly prohibited Evidence=null. Frozen Models.psm1 line13 permits null Evidence, and New-NyxUnknownResult intentionally uses it for unavailable probes. User authorized evidence-only correction. Neither authoritative JSON nor product changed.

Four bounded positive UI observations: progress and Cancel visible during real Quick; exact Enter detail after re-render; keyboard Close; exact double-click after away/back recreation. UI completion observation is backed by quick-authoritative.json and corrected validation, not screenshots alone.

Native nonadmin PS5.1 session: 120 DPI, physical1366x768, work area1366x708, PMv2 observer true. App observed absent three samples at 04:26:16.1393810Z. Not scan-worker/temp-cleanup proof. No complete F008 acceptance cell counted. Historical staging CANDIDATE.json is not a current verdict. Raw inherited logs remain raw.

HOLD / INCOMPLETE: full focused F023, F022 geometry, F020/F015, full132-cell F008 and downstream native suites outstanding. No Independent QA PASS. SHA256SUMS covers exact bytes of all files except itself; Git * -text retains them.
