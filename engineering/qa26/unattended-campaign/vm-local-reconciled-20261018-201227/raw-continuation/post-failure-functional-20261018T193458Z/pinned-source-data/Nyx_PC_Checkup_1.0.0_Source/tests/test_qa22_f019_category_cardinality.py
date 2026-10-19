from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'src/app/ui/MainWindow.psm1').read_text(encoding='utf-8-sig')


def test_every_category_helper_assignment_normalizes_pipeline_output():
    calls = re.findall(r'\$(?:results|groupResults)\s*=\s*(@\()?Get-NyxResultsByCategory\b', SOURCE)
    assert len(calls) == 3
    assert all(call == '@(' for call in calls)


def test_category_page_keeps_strictmode_and_no_data_branch():
    page = SOURCE.split('function Show-NyxCategoryPage {', 1)[1].split('function Show-NyxStoragePage', 1)[0]
    assert 'Set-StrictMode -Version 2.0' in SOURCE
    assert 'Set-StrictMode -Off' not in SOURCE
    assert 'catch' not in page
    assert '$results=@(Get-NyxResultsByCategory -Categories $Categories)' in page
    assert 'if($results.Count -eq 0)' in page
    assert 'New-NyxResultsGridControl -Results $results' in page


def test_native_regression_covers_cardinalities_and_navigation():
    probe = (ROOT / 'tests/powershell/Test-QA22CategoryCardinality.ps1').read_text(encoding='utf-8-sig')
    for required in ("@(0,1,2,12)", "@('Native','Deserialized')", "@('Backup','Security','Updates','System')", 'ConvertFrom-Json', 'foreach($repeat in 1..3)', 'Show-NyxHomePage', 'Show-NyxStoragePage', 'Rows.Count', 'Set-StrictMode -Version Latest'):
        assert required in probe
