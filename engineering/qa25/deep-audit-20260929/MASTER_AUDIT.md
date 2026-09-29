# QA25 deep audit — master index

The complete repository execution contract and source findings are in [README.md](README.md). Read that before running the supplemental evidence guard.

## Scope

Frozen product source: `f55c0d3bda6a99a20d218a2a390f217963a0d9be`.
Build: `2026.09.28-eng-qa25`.
Engineering issue: #14 / F-022.

**HOLD / native acceptance pending.** This branch adds documentation, an evidence checker and its tests only. It does not change the product, create QA26, execute Windows acceptance, or authorize public release.

## Files

- `README.md`: current identity; F-022 root cause and existing fix; A01-A08 source risks/test gaps; stronger cell-visibility contract; all-page coverage; scan/action/privacy/packaging precautions; finite continuation order and source anchors.
- `tools/qa25_evidence_guard.py`: read-only archive/hash, recorded geometry and F-008 coverage checks; `init-matrix` exclusively creates a new 132-cell NOT_RUN journal.
- `tests/test_evidence_guard.py`: 43 local self-tests for the guard, with fictional unit-test fixtures explicitly separated from native evidence.
- `SELF_TEST_SUMMARY.json`: local Linux/Python execution scope, counts and exact code hashes. No Nyx Windows tests ran here.

## Codex entry point

Keep the existing QA25 candidate artifacts frozen. Incorporate these files only in Engineering evidence/harness space, not product distribution. Fix the pending collector output path without bypassing security prompts. Verify current files and environment, then run the exact installed F-022 Apps 200% / 1366x768 case, cross-page Fill-grid readability preflight and the bounded source-risk diagnostics. Classify any genuine product failure before product changes. Evidence-only problems do not require a rebuild.

When focused checks pass, complete the established F-022/F-021/F-020/F-015, 132-cell F-008, Standard/Elevated/lifecycle/privacy gates. Reuse same-candidate evidence only for the predicates and context it actually proves. Record unmet gates instead of estimating a completion percentage. Independent QA owns the final verdict.
