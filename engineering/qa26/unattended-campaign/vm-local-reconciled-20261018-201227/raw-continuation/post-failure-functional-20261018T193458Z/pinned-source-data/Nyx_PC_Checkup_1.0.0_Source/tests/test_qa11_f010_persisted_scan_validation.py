from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "src" / "app" / "core" / "CheckupEngine.psm1"
MAIN_WINDOW = ROOT / "src" / "app" / "ui" / "MainWindow.psm1"
WORKER = ROOT / "src" / "app" / "workers" / "ScanWorker.ps1"
SMOKE = ROOT / "tests" / "powershell" / "Run-WindowsSmokeTests.ps1"


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def test_f010_has_one_save_and_load_validation_boundary() -> None:
    source = text(ENGINE)
    assert "function Convert-NyxScanResult" in source
    assert "function Convert-NyxPersistedScan" in source
    assert "$validated=Convert-NyxPersistedScan -Scan $Scan -AllowEmptyResults" in source
    assert "$validated=Convert-NyxPersistedScan -Scan $scan" in source
    assert "Persisted scan state was rejected" in source
    for field in ("CheckId", "Category", "Name", "Status", "Severity", "Finding", "Reason", "Recommendation", "Complete"):
        assert f"'{field}'" in source
    for status in ("Good", "NeedsAttention", "Optional", "Unknown"):
        assert f"'{status}'" in source


def test_f010_worker_normalizes_before_summary_and_persistence() -> None:
    source = text(WORKER)
    assert "Convert-NyxScanResult -Result $value" in source
    assert "-FallbackCheckId $task.Id" in source
    assert "-NormalizeInvalid" in source
    assert "$results.Add($normalized)" in source
    assert "-Payload $normalized" in source


def test_f010_native_smoke_covers_malformed_and_partial_state() -> None:
    source = text(SMOKE)
    for marker in (
        "invalid persisted JSON is ignored safely",
        "unsupported schema",
        "missing Results",
        "null Results",
        "empty Results",
        "result missing {0}",
        "unsupported result Status",
        "valid partial cancelled scan loads safely",
        "malformed producer output normalizes to honest Unknown",
    ):
        assert marker in source


def test_invalid_persisted_json_is_caught_as_a_terminating_parse_error() -> None:
    source = text(ENGINE)
    assert "ConvertFrom-Json -ErrorAction Stop" in source
    assert "Persisted scan state could not be read and was ignored." in source


def test_persisted_scan_converter_does_not_leak_generic_list_add_indices() -> None:
    source = text(ENGINE)
    assert "[void]$results.Add($normalized)" in source


def test_partial_scan_empty_categories_are_safe_under_strict_mode() -> None:
    source = text(MAIN_WINDOW)
    assert "$null -ne $_ -and $null -ne $_.PSObject.Properties['Status']" in source
