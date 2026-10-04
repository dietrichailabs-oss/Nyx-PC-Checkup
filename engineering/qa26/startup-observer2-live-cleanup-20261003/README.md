# QA26 corrected observer: strict 125% live cleanup

Evidence only. Frozen QA26 product source remains 0303a78a06f67252c86634cd73f1e4bda32dd3cc. No rebuild or successor.

The original observer inspected the wrong TEMP folder. Those historical records remain preserved and are not cleanup proof. Observer v2 records the actual Nyx LocalAppData temp folder, native processes, stable authoritative result snapshots, and all-users Startup-folder hashes.

Three new Full completions validate 21 results each. One genuine cancelled Full validates 15 partial results. The initial 16-result cancelled snapshot is an older baseline, not a fifth new run. Two cancellation attempts completed before cancellation took effect and receive no cancellation credit.

At 23:56:48 UTC, while the installed app was still running and before VM shutdown, worker count was zero and the actual temp folder contained no artifacts. Later normal-close records show no application process. There were no remaining files for idle exclusive-read probes; this does not assert an active-file deletion test. All-users Run and Startup-folder hashes remained unchanged. Fixture was removed.

Focused F-015 remains incomplete pending the remaining strict contexts. No full F-008 cell is credited from these partial observations. Independent QA owns acceptance.
