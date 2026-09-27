# QA19 native continuation: Engineering stop
Same immutable candidate, no rebuild, no product edit, no QA20.
The completed installed Full scan at 2026-09-27T13:53:16.7665256Z to 13:53:32.5880255Z persisted valid JSON but contains two failed checks:
- performance.snapshot: missing TotalSeconds property while obtaining CPU.
- apps.inventory: missing SystemComponent property.
Both return Unknown, Complete=false, with ErrorReason. Application logs corroborate these errors.
This is not a recurrence of the progress sharing abort. A UI completion or valid JSON does not mean every product check succeeded.
Testing stops under the user's stop-on-first-genuine-product-failure rule. Independent QA owns final disposition.
No source correction was attempted.

The guest export replaces unreliable live-checkpoint extraction. Its 41 payload files were hash-verified after extraction.
PRE_SHUTDOWN_CLEANUP.json was recorded inside the running guest before shutdown: zero workers and zero stale scan artifacts. No separate synthetic handle-deletion test was performed.
Two observers ran concurrently during the latest Quick/Full pair; counts are per reader, not separate scans.
The earlier observer also captured the 09:39 Quick run, which had initially been withheld because the live checkpoint appeared to lack its records.
Thus three new completed runs have observer schema-validation evidence (two Quick, one Full). This does not retroactively validate every earlier run.
The baseline cancelled Full record is preserved but is not a new cancellation test.
Guest-export SHA256SUMS.json applies only to its own directory. This evidence-only commit also includes screenshots, harness files and this summary.
The ZIP is a guest evidence transport only; it contains no repackaged candidate. Frozen artifacts and existing release assets remain unchanged.
