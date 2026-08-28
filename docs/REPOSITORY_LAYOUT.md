# Repository Layout

`product/` is intentionally an isolated build root.

This avoids GitHub-only metadata such as `.github/`, PR templates, QA ledgers, and repository governance files entering Nyx PC Checkup's deterministic Source ZIP.

Build commands should run from `product/`.

Large immutable QA handoff ZIPs are not stored in Git. Store their SHA-256, filename, verdict, and routing in `qa/` and the relevant issue/PR.
