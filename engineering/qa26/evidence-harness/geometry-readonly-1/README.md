# QA26-GEOMETRY-READONLY-1 evidence observer

Evidence tooling only. Candidate QA26-F023-PS51-26 and product source0303a78a06f67252c86634cd73f1e4bda32dd3cc remain unchanged.

Both scripts parsed with zero diagnostics under native Windows PowerShell5.1. Staging status is not a runtime test PASS. The observer reads the exact installed WinForms controls in process and records rectangles, clipping ancestors, grid columns/cells/text measurement, DPI/work area, and focus. It does not inject inputs, modify controls or write product files. It is a diagnostic launch of the installed script, not proof of native EXE launch. The staging helper creates a separate guest harness and a disposable-user evidence startup entry, preserving frozen candidate files.

Runtime and metric evaluation are pending. A harness error must be classified as evidence-tooling failure, not automatically as a product defect. No full F-022/F-008 PASS or final handoff claim.
