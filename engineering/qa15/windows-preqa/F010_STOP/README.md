# QA15 strict continuation checkpoint

Status: **HOLD - F-010 cancellation matrix stopped before the requested storage/profile timing boundary.**

- Build: `2026.09.01-eng-qa15`
- Product bytes: unchanged
- Harness-only timestamp correction: `QA15-F012-TIMESTAMP-1`
- Corrected F-012: 17/17 PASS
- F-010 cancellation/relaunch: 41/42 checks passed before stop
- Failed check: `Cancel during storage/profile enumeration reaches requested timing boundary`
- Expected progress pattern: `(?i)(storage|profile)`
- F-010 malformed-state matrix: NOT RUN
- Elevated: NOT RUN
- F-008 complete matrix: NOT RUN

The run stopped according to Independent QA policy. Engineering has not classified this observation as a product defect and has not claimed Independent QA PASS.
