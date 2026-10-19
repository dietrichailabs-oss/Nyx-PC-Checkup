from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTROLS = (ROOT / 'src/app/ui/Controls.psm1').read_text(encoding='utf-8-sig')
MAIN = (ROOT / 'src/app/ui/MainWindow.psm1').read_text(encoding='utf-8-sig')


def test_every_factory_grid_registers_shared_visibility():
    factory = CONTROLS.split('function New-NyxGrid {', 1)[1].split('function ', 1)[0]
    assert 'Register-NyxGridFocusVisibility -Grid $grid' in factory
    assert '$control -isnot [Windows.Forms.DataGridView]' in MAIN


def test_grid_state_does_not_replace_page_tag_or_capture_expired_locals():
    helper = CONTROLS.split('function Register-NyxGridFocusVisibility {', 1)[1].split('function ', 1)[0]
    assert '$Grid.Tag=' not in helper
    assert 'NyxGridFocusState' in helper
    assert '$sender.Tag' in helper
    assert '$Grid.Add_CurrentCellChanged({param($sender,$eventArgs)' in helper
    assert '$Grid.Add_Disposed({' in helper
    assert '$sender.NyxGridFocusState.Timer.Dispose()' in helper


def test_cell_geometry_is_mapped_through_scrollable_ancestors():
    helper = CONTROLS.split('function Show-NyxGridCurrentCell {', 1)[1].split('function ', 1)[0]
    for token in ('FirstDisplayedScrollingRowIndex', 'HorizontalScrollingOffset',
                  'GetCellDisplayRectangle', 'RectangleToScreen', 'RectangleToClient',
                  'AutoScrollPosition', '$parent=$parent.Parent', 'finally'):
        assert token in helper
    assert 'catch' not in helper
    assert 'ContainsFocus' in helper and 'IsDisposed' in helper


def test_manual_scroll_is_not_reversed_by_a_scroll_event_subscription():
    helper = CONTROLS.split('function Register-NyxGridFocusVisibility {', 1)[1].split('function ', 1)[0]
    assert 'Add_Scroll' not in helper and 'Add_MouseWheel' not in helper
    assert 'Add_KeyUp' in helper


def test_native_geometry_regression_covers_navigation_and_repopulation():
    test = (ROOT / 'tests/powershell/Test-QA23GridFocusVisibility.ps1').read_text(encoding='utf-8-sig')
    for token in ('PageDown', 'PageUp', 'Home', 'End', 'SelectNextControl',
                  'Rows.Clear()', '1.25', '1.5', '2.0', 'manual scroll',
                  'FirstDisplayedScrollingRowIndex', 'RectangleToScreen'):
        assert token in test
