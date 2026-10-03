# QA26 owner-approved DPI acceptance policy

Effective: 2026-10-03, America/New_York. Product owner decision recorded during QA26 continuation.

## Immutable candidate

- Source: `0303a78a06f67252c86634cd73f1e4bda32dd3cc`
- Build: `2026.10.02-eng-qa26`
- Harness: `QA26-F023-PS51-26`
- Candidate: `qa26-f023-candidate-20261002`
- No rebuild, product-source change, candidate repackaging, or QA27 is authorized by this policy change.

## Support statement

Owner-approved release documentation wording:

> Nyx PC Checkup is fully validated at Windows display scaling up to 150%. 200% scaling is supported on a best-effort basis; scrolling or reduced visible content may be required on constrained displays.

This wording defines the support target. QA26 acceptance remains incomplete: it must not be presented as proof that the pending validation has already passed. Use the validation claim in release documentation only after the required acceptance is completed and Independent QA issues its decision.

## Fully supported scales

100%, 125%, and 150% retain strict release-blocking visual, keyboard, readability, scrolling, action-access, and work-area requirements. Constrained 1366x768 coverage remains required where applicable. Do not relax these scales because 200% has limited support.

## Best-effort 200% coverage

At 200%, verify launch, reachability of every page and primary action, functional keyboard navigation, practical scrolling, ultimately readable essential information, absence of crashes/unhandled exceptions, and preservation of destructive-action safety and privacy/security.

Material failures still stop acceptance: crash, unhandled exception, impossible required navigation, inaccessible primary action, completely lost keyboard focus without practical recovery, essential information unreadable without a reasonable navigation/scroll route, corruption/loss, safety/privacy/security regression, or fundamental unusability.

Partial-cell geometry, ordinary horizontal/vertical scrolling, recoverable awkward focus positioning, nonessential truncation, cosmetic clipping/spacing, and reduced visible content are not blockers by themselves. Record limitations explicitly; do not claim perfect 200% presentation.

## Existing stopped observation

Retain the immutable stopped-run evidence at commit `da588db8cbb8fe2fd6c9769327c8f002215ebc1b` and release `qa26-f022-200pct-focus-review-20261003`. Do not rewrite or falsify it.

The Version column nominal width of 300 pixels versus a recorded displayed width of 231 pixels is not, by itself, a release blocker or a formally classified new defect. Resume acceptance on the same product bytes. Determine material readability and practical keyboard/scroll recovery under this revised policy; retain the original settled screenshots and observer limitations.

## Matrix and reporting

The 132 theme/scale/page cells remain: 99 strict cells (3 themes x 3 fully supported scales x 11 pages), plus 33 best-effort functional/accessibility cells (3 themes x 200% x 11 pages).

Every accepted cell requires the applicable checklist, not merely page-open observations. Record support tier, tested criteria, outcome, findings/limitations, and evidence paths. Distinguish strict PASS from best-effort functional PASS with limitations. At policy adoption, complete accepted F-008 cells remain 0/132; no prior partial observations are automatically promoted.

Continuation order: F-023 reconciliation; F-022 revised-policy closeout; F-020/F-015 strict 100/125/150 and best-effort 200; remaining F-008 cells; Standard/Smoke/migration/privilege/installer lifecycle; F-011/F-012/F-010/F-016; Elevated; remaining privacy/safety/lifecycle gates.

Stop at the first genuine product failure. Evidence/harness problems alone do not authorize a product rebuild. Independent QA owns final PASS / HOLD / FAIL under this revised policy.
