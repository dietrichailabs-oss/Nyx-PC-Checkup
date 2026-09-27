from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'src/app/ui/MainWindow.psm1').read_text(encoding='utf-8-sig')
PAGE = SOURCE.split('function Show-NyxStartupPage {', 1)[1].split('function Show-NyxAppsPage', 1)[0]


def test_startup_all_five_deferred_handlers_use_explicit_sender_state():
    handlers = re.findall(r'\$(\w+)\.Add_(Click|SelectionChanged)\(\{(.*?)\n    \}\)', PAGE, re.S)
    assert {(name, event) for name, event, _ in handlers} == {
        ('grid', 'SelectionChanged'), ('refresh', 'Click'), ('disable', 'Click'),
        ('enable', 'Click'), ('location', 'Click'),
    }
    for name, _, body in handlers:
        assert 'param($sender,$eventArgs)' in body, name
        assert '$sender.Tag' in body, name
        assert not re.search(r'\$(grid|refresh|disable|enable|location|load|startupState)\b', body), name


def test_startup_reload_is_real_and_selection_safe():
    reload = SOURCE.split('function Update-NyxStartupRows {', 1)[1].split('function Show-NyxStartupPage', 1)[0]
    assert 'Get-NyxStartupApplications' in reload
    assert '$State.Grid.Rows.Clear()' in reload
    assert '$State.Grid.Rows.Add(' in reload
    assert '$State.Grid.ClearSelection()' in reload
    assert 'finally' in reload and '$State.Loading=$false' in reload
    assert 'catch' not in reload
    assert 'Set-StrictMode -Off' not in SOURCE


def test_startup_state_is_shared_by_every_event_sender():
    assert 'foreach($control in @($grid,$refresh,$disable,$enable,$location)){$control.Tag=$startupState}' in PAGE
    assert PAGE.count('Update-NyxStartupRows -State $state') == 2
    assert "Operation='DisableStartup'" in PAGE
    assert "Operation='EnableStartup'" in PAGE
    assert "Invoke-NyxOpen 'explorer.exe'" in PAGE
    assert PAGE.count('if(-not [bool]$app.CanModify)') == 2


def test_deferred_runtime_regression_is_shipped():
    probe = (ROOT / 'tests/powershell/Test-QA18StartupDeferredState.ps1').read_text(encoding='utf-8-sig')
    assert 'Set-StrictMode -Version Latest' in probe
    assert 'Show-NyxStartupPage' in probe
    assert 'OnClick' in probe
    assert 'Invoke-DeferredClick' in probe
    assert 'all-users' in probe
