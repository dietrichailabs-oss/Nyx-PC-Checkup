# QA22 Engineering evidence return

Status: HOLD / INCOMPLETE ACCEPTANCE. This is new evidence, not a completed QA acceptance handoff.

Candidate 2026.09.27-eng-qa22 remains frozen. No rebuild, source change, QA23, or product repackaging was performed.

F-019 installed cardinality is recorded PASS. F-018 five consecutive Full Checks are PASS. Nine additional F-016 results validate, including one cancelled Full Check; all have live pre-shutdown worker/artifact cleanup. Shared-reader totals are 12,566 including the five F-018 runs.

Immediate Quick-to-Full and Full-to-Quick remain unproven: the tighter run gaps were 8.995 and 9.169 seconds. These are NOT certified as immediate. The later ordered gates are not claimed or counted.

The existing frozen product assets are retained at:
https://github.com/dietrichailabs-oss/Nyx-PC-Checkup/releases/tag/qa22-f019-candidate-20260927

Source commit: 958813267b6f69466770701816146de234cf1388
Harness: QA22-F019-PS51-22

Evidence includes original guest JSON, concurrent progress read snapshots/counts, live cleanup records, installed identity comparisons, UI screenshots, and evidence-only helpers. Baseline results are excluded from run totals. The older F018 report's ProgressFiles field serialized as five 1 entries; its intended count is five, as the raw read-count file confirms. Original records are preserved rather than silently rewritten.

Independent QA owns PASS / CONDITIONAL PASS / HOLD / FAIL. This return establishes no new product defect and does not authorize release.
