from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'src/app/ui/MainWindow.psm1').read_text(encoding='utf-8-sig')


def test_result_and_storage_share_primary_action_registration():
    assert 'Register-NyxGridPrimaryAction -Grid $grid -Action' in SOURCE
    assert 'Register-NyxGridPrimaryAction -Grid $lg -Action' in SOURCE
    assert SOURCE.count('.Add_CellDoubleClick(') == 1


def test_enter_is_input_and_suppresses_default_row_movement():
    assert '$eventArgs.IsInputKey=$true' in SOURCE
    assert '$eventArgs.Handled=$true' in SOURCE
    assert '$eventArgs.SuppressKeyPress=$true' in SOURCE
    assert '$eventArgs.KeyData -eq [Windows.Forms.Keys]::Enter' in SOURCE


def test_primary_action_validates_lifetime_and_restores_focus():
    helper = SOURCE.split('function Invoke-NyxGridPrimaryAction {', 1)[1].split('function Register-NyxGridPrimaryAction', 1)[0]
    for predicate in ('IsDisposed', 'Disposing', '$null -eq $cell', '$row.IsNewRow', '$null -eq $row.Tag', '$state.Busy'):
        assert predicate in helper
    assert 'finally{' in helper
    assert '$Grid.CurrentCell=$cell' in helper
    assert '[void]$Grid.Focus()' in helper
    assert 'catch' not in helper


def test_registered_handlers_use_sender_not_expired_grid_local():
    register = SOURCE.split('function Register-NyxGridPrimaryAction {', 1)[1].split('function New-NyxResultsGridControl', 1)[0]
    assert register.count('param($sender,$eventArgs)') == 3
    assert register.count('Invoke-NyxGridPrimaryAction -Grid $sender') == 2
    assert 'NyxPrimaryActionState' in register
    assert "'Press Enter or double-click a result" in SOURCE
