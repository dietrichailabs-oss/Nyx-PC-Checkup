# QA26 strict 100% Startup checkpoint

Evidence-only; frozen QA26 unchanged. Original screenshots preserve Refresh x3, approved current-user missing-target fixture disable/Refresh/restore/Refresh, keyboard-visible focus, all-users read-only actions, valid keyboard Open location, handled unavailable location, navigation away/back, post-Quick/Full/cancel Refresh, horizontal keyboard scrolling and reverse navigation.

DPI sign-out terminated the original observer without removing its fixture. The next observer refused the existing fixture, so its incomplete output receives no live-cleanup credit. The original cancelled result was still preserved and validates 11 partial results. Quick/Full contracts from that initial session were not retained; no contract credit is claimed for them.

Approved observer recovery recognizes only its own exact fixture name/value, refuses mismatches or an existing target, removes that fixture and allows the existing observer to recreate it. The frozen product and original observer are unchanged. The staging script completed staging but left the VM off; a separate exact-VM start was used. No product defect is established.

Recovered session: Quick 15 results; Full 21; genuinely cancelled Full 11. All 47 new result contracts PASS, ReadOnly true, correct Cancelled flags, no WorkerError. Initial 11-result cancellation is baseline, not a fourth new scan. At 00:25:22.7782995Z before shutdown, native installed app remained running, worker count zero, actual LocalAppData temp directory empty. Subsequent normal-close samples have no app process. All-users Run and Startup file hashes unchanged; observer fixture removed.

Native 100% DPI measurement remains pending geometry reconciliation. F-015, F-020 and F-022 remain incomplete. No complete F-008 cell is claimed. Independent QA owns acceptance.
