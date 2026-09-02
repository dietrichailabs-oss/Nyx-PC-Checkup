# Nyx PC Checkup QA15 F-008 Normal-VM Failure Handoff

Disposition: BLOCKED - genuine F-008 failure evidence requires Independent QA review.

Candidate build: 2026.09.01-eng-qa15
Candidate modified: No

## Frozen candidate hashes

- Setup: B4F082A79D76E2A7E9452B2717D87698ED136E4D10CFF2D4232DB6E0BF02CD80
- Portable: 6262B9EF383BA3C6AAF0D7BF192B7104EA0CBB3C9799DF55EA30F44A005A370A
- Source: E9D426CDCEB554AC071532C6079F421B47558A537A037CDC221958945E2AD62B
- Source tree: CC58B192CD27F286A041B67510BAF4C7D2097F996D0206DEAE4906BC555A11A0

## F-008 result

The normal disposable Hyper-V Windows VM driver stopped at the first matrix cell:

- Theme: Follow Windows
- Scaling: 100%
- Page: Home
- Result: FAIL
- Finding: Nyx window exceeded the available screen bounds.

No later matrix cells were executed. No product or harness correction was applied. Return to Independent QA for classification before any Engineering change.
