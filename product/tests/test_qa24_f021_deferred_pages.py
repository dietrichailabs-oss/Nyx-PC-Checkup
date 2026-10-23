from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / 'src/app/ui/MainWindow.psm1').read_text(encoding='utf-8-sig')


def section(name):
    return MAIN.split('function ' + name + ' {', 1)[1].split('\nfunction ', 1)[0]


def test_apps_callbacks_resolve_sender_state_not_constructor_locals():
    page = section('Show-NyxAppsPage')
    for token in ('Search=$search', 'Grid=$grid', 'Folder=$folder', 'Apps=$apps',
                  'Update-NyxAppsRows -State $sender.Tag',
                  'Update-NyxAppsSelection -State $sender.Tag',
                  'Open-NyxAppsSelectedFolder -State $sender.Tag'):
        assert token in page
    assert '$render' not in page


def test_render_resets_stale_selection_and_preserves_filtering():
    render = section('Update-NyxAppsRows')
    for token in ('[regex]::Escape($filter)', '$State.Apps', '$State.Search.Text',
                  '$State.Grid.CurrentCell=$null', '$State.Grid.ClearSelection()',
                  '$State.Loading=$true', '$State.Loading=$false'):
        assert token in render
    assert 'catch' not in render


def test_cleanup_callbacks_also_use_stable_state():
    page = section('Show-NyxCleanupPage')
    for token in ('Update-NyxCleanupSelection -State $sender.Tag',
                  'Invoke-NyxCleanupSelection -State $sender.Tag',
                  '$sender.IsCurrentCellDirty', '$sender.CommitEdit'):
        assert token in page
    assert '$update=' not in page
    assert "'Confirm destructive cleanup action'" in section('Invoke-NyxCleanupSelection')


def test_disposed_page_state_is_rejected_without_exception_swallowing():
    guard = section('Test-NyxDeferredPageState')
    for token in ('$State.Active', '$control.IsDisposed', '$control.Disposing'):
        assert token in guard
    for name in ('Update-NyxAppsRows', 'Update-NyxAppsSelection',
                 'Open-NyxAppsSelectedFolder', 'Update-NyxCleanupSelection',
                 'Invoke-NyxCleanupSelection'):
        assert 'Test-NyxDeferredPageState' in section(name)
        assert 'catch' not in section(name)
    assert 'Set-StrictMode -Version 2.0' in MAIN


def test_native_regression_executes_deferred_events_and_audits_free_variables():
    text = (ROOT / 'tests/powershell/Test-QA24DeferredPages.ps1').read_text(encoding='utf-8-sig')
    for token in ('Get-CallbackHazards', 'negative control', 'PerformClick()',
                  'publisher match', 'no-match', 'disposed', 'OnTextChanged',
                  'OnSelectionChanged', 'OnCurrentCellDirtyStateChanged',
                  'Show-NyxPage', 'CellValueChanged'):
        assert token in text
