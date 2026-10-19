# QA24 F-021 deferred callback audit

Build: 2026.09.27-eng-qa24. Harness: QA24-F021-PS51-24.

All event registrations in src/app/ui and the remainder of src/app were inspected.

| Area | Lifetime assessment | Correction |
| --- | --- | --- |
| Apps TextChanged, SelectionChanged, folder Click | Constructor locals expire | Shared sender.Tag state; named render/selection/folder functions; disposal and loading guards |
| Cleanup CellValueChanged, CurrentCellDirtyStateChanged, review Click | Constructor locals expire | Shared sender.Tag state; named summary/review functions; disposal guards |
| Startup | F-015 sender.Tag state already stable | Preserved |
| Settings save | F-012 sender.Tag state already stable | Preserved |
| Other page actions | Constant commands or callback-local variables, not constructor captures | Preserved |
| Result/file grid double-click | Sender row Tag and callback-local variables | Preserved |
| Controls focus, current-cell, key, size, disposed and timer callbacks | Sender state or script/module functions; F-020 separate grid property | Preserved; page Tag remains compatible |
| Navigation, scan/update timers | Sender Tag or module-owned NyxUi | Preserved |
| Main form Shown/FormClosing/FormClosed timers | Owning Show-NyxMainWindow stays active through Application.Run; timers closed before return | Audited bounded-lifetime exception, preserved |
| Modal detail/report/update dialog callbacks | Owning function stays active through ShowDialog; no callback survives dialog close | Audited bounded-lifetime exception, preserved |
| Category action scriptblock parameter | Registered scriptblock value supplied by constant Show-NyxPage actions; no constructor-local capture in its body | Preserved |

Apps filtering retains the complete inventory in its page state. Every render
clears CurrentCell and selection while Loading is true, leaving the folder action
disabled until a new selection. Empty/no-match inventories remain valid. Disposing
any referenced control makes the state unusable; grid disposal invalidates Active.
An old callback cannot reach the new page through a global page-state slot.

Cleanup retains exact candidate IDs, byte totals, explicit confirmation and worker
behavior. The source test mocks only external open/message/action boundaries; it
never deletes files or changes startup state. Actual native installed tests remain
required before any acceptance claim.

The native regression audits event callback free variables using PowerShell ASTs,
with explicit owner-lifetime exceptions above and a negative control containing
the original unsafe Apps callback. It exercises actual event handlers after the
page constructor has returned, including old disposed page callbacks.
