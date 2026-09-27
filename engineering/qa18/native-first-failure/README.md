# QA18 Engineering return: Full Check failure during focused F-015

Engineering status: FAIL / stopped, awaiting Independent QA classification.
No final product approval or Independent QA PASS is claimed.

Candidate: 2026.09.26-eng-qa18; harness QA18-F015-PS51-18.
Source commit: 9cdf56b6c3bc6e105035df328c902d0af12f781c.
Branch: eng/f015-startup-deferred-state.

The F-015 correction gives all five deferred Startup handlers persistent sender-owned state. StrictMode, real inventory reload, current-user reversible actions, and all-users guards remain. Frozen QA17 artifacts/evidence were not edited. QA18 was not modified or rebuilt after native testing started.

Native sequence: fresh installed launch; Startup Refresh; three further Refresh clicks; select row; navigate Home -> Startup -> Refresh; complete Quick Check; Startup -> Refresh; start Full Check and wait without pressing Cancel. Full Check stopped unexpectedly. Screenshot FULL_CHECK_STOPPED_UNEXPECTEDLY.png captures the visible message. App log at 2026-09-27T01:25:13.1796492Z reports a sharing violation on its scan progress.jsonl file. The lock owner and exact root cause are not established. No retry, repair or continuation after failure.

The real native EXE was started directly, without the QA17 debugger observation wrapper. Setup returned 0 under native Windows PowerShell 5.1. The VM retained the prior 200% / 1366x768 display. Fresh numeric DPI measurement was not collected in this QA18 run, so the display setting is inherited evidence, not a new API measurement. This was a checkpoint-preserved upgrade profile, not a clean Standard acceptance run.

Exact counts: Python 199/199; structural lint 2/2; isolated real-WinForms deferred-event regression 14/14 on host and 14/14 against installed guest source. These isolated tests stub inventory, actions, dialogs and Explorer; they are not real registry transition evidence. Focused native list: 4 PASS, 1 FAIL, 4 INCOMPLETE, 6 NOT_RUN (15). The complete F008 matrix remains 132 NOT_RUN; earlier focused UI observations do not count as matrix PASS. All successor Standard/F011/F012/F010/Elevated/lifecycle gates remain NOT_RUN under stop policy.

Collected logs include historical entries from the retained profile; use the failure timestamp above. last-scan.json is retained data, not proof of a successful Full Check. The missing transient progress file was not recreated or fabricated. No full exception stack or lock-owner trace is available.

The Source ZIP is the authoritative byte-level source artifact; Git may normalize line endings. The failed preliminary build directory qa18_f015_build is not the candidate. Frozen files come only from qa18_f015_candidate_build. SHA256SUMS.txt covers every transport member except itself. Historical handoff ZIPs are not nested.

Routing: Engineering -> Independent QA, Issue #7. Please classify this observed Full Check failure before any further product correction.
