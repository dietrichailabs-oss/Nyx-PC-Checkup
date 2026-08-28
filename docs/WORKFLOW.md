# Engineering ↔ Independent QA Workflow

```text
Issue / QA finding
      ↓
Engineering branch
      ↓
Focused commits + tests
      ↓
Pull request / diff review
      ↓
Clean deterministic build
      ↓
Immutable candidate + hashes
      ↓
Independent QA
      ↓
PASS / CONDITIONAL PASS / HOLD / FAIL
```

GitHub is the working source-control backbone. Immutable QA ZIPs remain the release-gate evidence of record.

## Rules

- No silent source edits by QA.
- No Engineering self-approval.
- No replacing candidate bytes while retaining old hashes/names.
- No whole-project cache/build/evidence directories in source commits.
- Prefer focused modules and small correction branches.
- Keep Windows destructive tests on disposable environments.
- Carry all historical release-blocking findings forward until closed.
