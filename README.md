# Nyx PC Checkup

Nyx PC Checkup is Dietrich AI Labs' local-first Windows PC diagnostics and maintenance utility.

This **private standalone repository is the authoritative editable source-control home** for Nyx PC Checkup. Normal Engineering source control lives here; immutable Independent QA evidence remains hash-frozen outside normal Git history.

## Repository layout

- `product/` — buildable product source tree. Build and test from this directory.
- `engineering/` — current Engineering handoffs and correction notes.
- `qa/` — QA status, evidence identities, and routing. Large immutable QA ZIPs are not committed.
- `docs/` — repository workflow and project governance.
- `.github/` — pull request, issue, ownership, and CI scaffolding.

## Current state

Independent QA status: **FAIL — QA11-F-010**.

Active release blocker: **Issue #1 — QA11-F-010: validate persisted cancelled-scan state before relaunch.**

The current failed baseline is build `2026.08.27-eng-qa11`.

```text
Setup SHA-256:       2E4CE0BFE42C2E88548D3C8C039F3B2C04A829940A1A6444F9F333A665D71C26
Portable SHA-256:    810B93A242F539C86E657A192A88EDFB934402E5FBE24030F5CA5C1AB63EF07D
Source ZIP SHA-256:  19AAE16749580CA8023711E081B1DCFDC0728CA5C6301DD55716E385CA775470
Source tree SHA-256: C4273FA058A9151EF7E51EDE2EC264892CA707FF5957B7F5C39EA0DB7D599EAA
QA11 FAIL SHA-256:   E962569A552847A4FF9F6D08A165E4E1144B13ECB80A5D530AEE612BD0A4F820
```

The blocker is a cancelled Full Check persisting state that crashes the next UI launch when a persisted result does not satisfy the current result model.

See `engineering/F010_HANDOFF.md`, `qa/current/QA11_FAIL.md`, and Issue #1.

## Development workflow

1. Work from a focused Engineering branch.
2. Keep product source changes inside `product/` unless the change is repository tooling/docs.
3. Run local source tests and deterministic build from `product/`.
4. Open a PR with exact test counts and changed-file scope.
5. Engineering creates a new immutable candidate ZIP only after source review/testing.
6. Independent QA reviews the exact candidate and returns PASS / CONDITIONAL PASS / HOLD / FAIL.
7. Do not rewrite history or silently modify QA-approved/failed candidate bytes.

Current Engineering branch:

`eng/f010-persisted-scan-validation`

## Quick local checks

```powershell
cd product
python tools/ps_lint.py src/app
python tools/ps_lint.py tests/powershell
python -m pytest -q
```

The documented full deterministic build remains in `product/docs/BUILD_AND_REPRODUCE.md`.

## Historical bridge

The former workspace under `dietrichailabs-oss/Nyx/projects/nyx-pc-checkup/` is retained only as a migration/status pointer. Do not maintain a second editable product tree there.
