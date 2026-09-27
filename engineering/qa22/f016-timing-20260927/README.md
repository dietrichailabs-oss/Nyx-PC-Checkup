# QA22 F-016 focused timing completion

Engineering result: all three previously missing F-016 cases PASS. Overall QA22 acceptance remains incomplete pending F-015, F-008 and the later ordered gates.

The full frozen installed runtime graph, actual WinForms UI loop/timers, unchanged Start-NyxScan and Cancel-NyxScan entry points, and actual installed ScanWorker were exercised. No extracted functions, substituted scans, edited result JSON, changed product bytes, or scan delays were used. This is an installed integration harness; it does not claim a new native-launcher acceptance run.

Quick cancellation: live worker PID 9668; Cancel requested 2026-09-27T20:13:44.0767453Z; completed 2026-09-27T20:13:44.1085756Z; Cancelled=true; two valid partial results; no WorkerError. Four authoritative results validate, all ReadOnly=true. Live product cleanup occurred after each worker exit; final live worker/artifact counts were zero.

Quick -> Full: previous completion 20:14:01.8895128Z; UI cleanup observed and next scan dispatched 20:14:02.1443980Z; next worker started 20:14:02.9698850Z. Dispatch delay 0 ms at recorded clock precision; total completion-to-worker-start 1080.3722 ms.

Full -> Quick: previous completion 20:14:20.9642045Z; UI cleanup observed and next scan dispatched 20:14:21.3299957Z; next worker started 20:14:22.1710344Z. Dispatch delay 0 ms at recorded clock precision; total completion-to-worker-start 1206.8299 ms.

No deliberate sleep, disk evidence serialization, or validation was inserted between observing product cleanup and dispatching the next scan. The measured total includes product cleanup and real Windows PowerShell worker startup.

60 installed payload files matched the exact frozen Portable before and after, with zero changed hashes. Build 2026.09.27-eng-qa22; product harness QA22-F019-PS51-22; evidence-only timing harness QA22-F016-TIMING-1. Product source 958813267b6f69466770701816146de234cf1388.

3,051 shared progress reads in this harness run; 15,617 accumulated including the prior 12,566. Independent QA owns final disposition. F-015 has begun but is not complete; the 132-cell F-008 and later suites are not claimed.
