# QA17 first product failure: Independent QA return

QA17 is stopped. No release approval or Independent QA PASS is claimed.

Candidate: 2026.09.26-eng-qa17 / QA17-F014-PS51-17.
Source commit: ea35cb79805718b2b68e147585df887b9623af56.
Branch: eng/f014-high-dpi-ui-clipping. QA16 remains untouched.

At Follow Windows, 200% (192 DPI), 1366x768, Startup > Refresh list raises an unhandled Windows Forms exception: "The variable '$grid' cannot be retrieved because it has not been set."

Reproduction observed: open Checkup; start Quick Check; cancel and wait for partial-results confirmation; open Startup; focus/scroll content to actions; click Refresh list.

The failure was observed once. Testing stopped immediately; Details was expanded solely to preserve evidence. No Continue, retry, fix, or rebuild followed. Exact root cause and dependence on the preceding cancellation are not established. Screenshots show the error; full exception stack was not extracted from the guest dialog.

The interactive failure occurred in the exact installed script via the read-only external breakpoint observer, not the initial native EXE process. Native EXE launch, process lineage, physical DPI, and bounds are independently recorded in the preceding observer result. No claim of instrumented/native process identity equivalence is made.

Partial checks reached Home scan actions, Settings, scrolling, visible focus, and Cancel Scan. They are not complete matrix PASS cells. F008_MATRIX.json contains 132 cells: 0 PASS, 1 FAIL, 4 INCOMPLETE, 127 NOT_RUN. The complete 200% first gate did not pass. Standard, F-011, F-012, F-010 and Elevated were not run.

Setup returned 0. Candidate hashes were checked before packaging. The unchanged Setup, Portable and Source are included; Source ZIP is the authoritative byte-level source artifact. Git may normalize text line endings. Build-time Python checks passed 195/195; these do not supersede native failure.

VM collection used graceful shutdown and read-only disk mounting. VM was left off. The first launch evidence and later screenshots have distinct capture times. A legacy qa16.f013.bounds.v1 schema string remains in the reused bounds observer output; it is not product identity. Candidate identity is recorded separately.

Routing: Engineering -> Independent QA. Please classify this first QA17 product failure before any successor correction. No historical handoff ZIPs are nested.
