from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / 'src/app/ui/MainWindow.psm1').read_text(encoding='utf-8-sig')


def test_apps_columns_have_explicit_non_fill_logical_policy():
    policy = MAIN.split('function Set-NyxAppsColumnPolicy {', 1)[1].split('function ', 1)[0]
    for token in ("AutoSizeColumnsMode='None'", "ScrollBars='Both'", 'MinimumWidth',
                  "@('Name',240)", "@('Publisher',200)", "@('Version',150)",
                  "@('Date',130)", "@('Size',150)"):
        assert token in policy
    page = MAIN.split('function Show-NyxAppsPage {', 1)[1].split('function ', 1)[0]
    assert 'Set-NyxAppsColumnPolicy -Grid $grid' in page
    assert 'Font=' not in policy


def test_policy_is_apps_only_and_not_reset_by_filter():
    render = MAIN.split('function Update-NyxAppsRows {', 1)[1].split('function ', 1)[0]
    assert 'Columns.Clear' not in render
    assert 'AutoSizeColumnsMode' not in render
    assert MAIN.count('Set-NyxAppsColumnPolicy -Grid') == 1


def test_geometry_covers_readability_not_just_positive_intersection():
    harness = (ROOT / 'tests/powershell/Test-QA25AppsColumnReadability.ps1').read_text()
    for token in ('MeasureOnly', 'MinimumWidth', 'ClientSize', 'MeasureText',
                  'HorizontalScrollingOffset', 'SelectNextControl', 'PageUp', 'PageDown',
                  'Show-NyxPage -Page Apps', 'Search.Text', '1.25', '1.5', '2.0',
                  'visible.Width -ge $whole.Width-2'):
        assert token in harness


def test_geometry_snapshots_width_before_minimum_can_clamp_it():
    controls = (ROOT / 'src/app/ui/Controls.psm1').read_text(encoding='utf-8-sig')
    geometry = controls.split('function Set-NyxDeviceGeometry {', 1)[1].split('\nfunction ', 1)[0]
    assert geometry.index('$scaledWidth=[int]($column.Width*$r)') < geometry.index('$column.MinimumWidth=$scaledMinimum')
    assert '$column.Width=[math]::Max($scaledMinimum,$scaledWidth)' in geometry
