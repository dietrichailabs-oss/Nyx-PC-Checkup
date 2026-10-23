# QA15 PATH1 Windows checkpoint

Status: **HOLD - F-012 regression failed; later phases were not run.**

- Frozen build: `2026.09.01-eng-qa15`
- Frozen harness/product candidate: `QA15-F012-PS51-15`
- Harness-only correction: `QA15-F011-PATH-1`
- Corrected Standard: PASS
- Smoke: 122/122 PASS
- Standard privilege/rollback: 12/12 PASS
- QA2 migration: 244/244 PASS
- Standard installer lifecycle: 44/44 PASS
- F-011 installed launch: 39/39 PASS
- Dedicated F-012: 16/17 PASS, 1 FAIL
- Failure: `F-012 saving Settings preserves unrelated update timestamp`
- Observed detail: `08/31/2026 20:00:00`

Execution stopped after F-012. F-011 confirmation, F-010, Elevated, and F-008 were not run in this sequence.

No product or candidate bytes were rebuilt or modified. This is Engineering evidence for Independent QA review and is not an Independent QA PASS.
