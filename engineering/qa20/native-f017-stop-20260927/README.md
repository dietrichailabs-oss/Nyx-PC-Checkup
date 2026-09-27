# QA20 installed F-017 gate: stop on first Full run
Frozen QA20 product unchanged. No rebuild or successor created.
The first Full Check completed with valid authoritative JSON, but apps.inventory returned Unknown / Complete=false with ErrorReason:
The property 'Properties' cannot be found on this object. Verify that the property exists.
The application log corroborates this at 2026-09-27T14:31:16.9487947Z.
performance.snapshot returned Good / Complete=true without the prior CPU/TotalSeconds error.
Full scan: 2026-09-27T14:30:52.2033162Z through 14:31:16.9646568Z.
Focused result: 0 passed, 1 failed, 4 not run. Stop-on-first-genuine-product-failure honored.
Observer: 1535 progress reads; no progress-sharing abort observed in this run.
Guest pre-shutdown record: zero workers, zero stale scan artifacts. Independent synthetic handle-deletion test not performed.
61 installed-file hashes matched. Guest ZIP and all 20 manifest payload files verified after retrieval.
The observer baseline RESULT_A638... is inherited QA19 state, not a QA20 run.
Installed acceptance failure supersedes source-function unit success; no final QA disposition is claimed.
Guest-export SHA256SUMS.json covers that directory only. Screenshots and Engineering summary are separate review evidence.
