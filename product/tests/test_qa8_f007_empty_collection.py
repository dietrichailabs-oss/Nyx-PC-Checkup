from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
CLEANUP = ROOT / "src" / "app" / "checks" / "CleanupScan.psm1"
DOWNLOADS = ROOT / "src" / "app" / "checks" / "DownloadsAnalysis.psm1"
SMOKE = ROOT / "tests" / "powershell" / "Run-WindowsSmokeTests.ps1"


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def test_no_measure_object_sum_remains_in_shipped_runtime():
    hits=[]
    for path in (ROOT / "src" / "app").rglob("*.ps*"):
        source=text(path)
        if re.search(r"Measure-Object[^\r\n]*-Sum", source, re.I):
            hits.append(str(path.relative_to(ROOT)))
    assert hits == []


def test_cleanup_total_is_explicit_int64_zero_safe_accumulation():
    source=text(CLEANUP)
    assert "function Get-NyxCleanupItemsTotalBytes" in source
    assert "[int64]$total=0" in source
    assert "foreach($item in $Items)" in source
    assert "$total=Get-NyxCleanupItemsTotalBytes -Items $items" in source
    assert "Cleanup candidate size cannot be negative." in source


def test_download_total_is_explicit_int64_zero_safe_accumulation():
    source=text(DOWNLOADS)
    assert "function Get-NyxDownloadItemsTotalBytes" in source
    assert "[int64]$total=0" in source
    assert "foreach($item in $Items)" in source
    assert "$total = Get-NyxDownloadItemsTotalBytes -Items $Items" in source
    assert "Downloads item size cannot be negative." in source


def test_download_result_builder_uses_same_runtime_aggregation_path():
    source=text(DOWNLOADS)
    assert "function New-NyxDownloadsAnalysisResult" in source
    assert "return New-NyxDownloadsAnalysisResult -Downloads $downloads -Items $items" in source
    assert "TotalBytes=$total" in source


def test_windows_smoke_has_exact_f007_empty_state_regressions():
    source=text(SMOKE)
    for marker in [
        "F-007 zero cleanup candidate set returns a valid result",
        "F-007 zero cleanup candidate set reports TotalBytes zero",
        "F-007 empty Downloads returns a valid Good result",
        "F-007 empty Downloads reports TotalBytes zero",
        "F-007 non-candidate-only Downloads remains Good",
        "F-007 cleanup action safety revalidation remains fail-closed",
    ]:
        assert marker in source
    assert "HarnessRevision='QA19-F016-PS51-19'" in source
