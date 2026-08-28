# Contributing to Nyx PC Checkup

## Engineering lane

Engineering owns implementation, correction, tests, deterministic builds, and handoff preparation. Engineering does not approve its own release candidate.

Use focused branches such as:

```text
eng/f010-persisted-scan-validation
eng/f011-<finding>
chore/<scope>
```

Every product PR should include:

- linked GitHub issue;
- exact problem statement;
- changed-file list;
- local test counts;
- Windows evidence when available;
- whether product bytes changed;
- new Setup / Portable / Source hashes when a candidate is built;
- rollback/regression impact.

## Independent QA lane

Independent QA tests exact immutable candidate bytes and never silently edits Engineering source during a QA pass.

QA outcomes are:

- PASS
- CONDITIONAL PASS
- HOLD
- FAIL

QA evidence ZIPs remain immutable and normally live outside normal Git history. Commit identities/hashes and concise reports instead of giant handoff archives.

## Baseline rule

Do not overwrite or rewrite a failed/approved baseline. A product byte change creates a new candidate identity.
