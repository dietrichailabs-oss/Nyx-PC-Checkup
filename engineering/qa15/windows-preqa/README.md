# QA15 Windows pre-QA checkpoint

Build: `2026.09.01-eng-qa15`  
Harness: `QA15-F012-PS51-15`

Standard stopped on one F-011 evidence assertion:

- Smoke: 122/122 PASS
- Standard privilege/rollback: 12/12 PASS
- QA2 migration: 244/244 PASS
- Standard installer lifecycle: 44/44 PASS
- F-011 installed launch: 38/39 PASS
- Failure: setup exited 0 but did not create the requested branch-specific diagnostics JSON.

Per gate policy, F-012, F-011 follow-up, F-010, Elevated, and F-008 were not run after Standard failed.

This is Engineering evidence only. It is not an Independent QA PASS.
