from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATHS = ROOT / "src" / "app" / "core" / "Paths.psm1"
COMPOSITION = ROOT / "src" / "app" / "core" / "RuntimeComposition.psm1"
MAIN = ROOT / "src" / "app" / "ui" / "MainWindow.psm1"
APP = ROOT / "src" / "app" / "NyxPCCheckup.ps1"
SMOKE = ROOT / "tests" / "powershell" / "Run-WindowsSmokeTests.ps1"
PLAN = ROOT / "docs" / "QA_TEST_PLAN.md"


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def test_f009_temp_cleanup_helper_is_bounded_and_zero_safe() -> None:
    source = text(PATHS)
    assert "function Remove-NyxTemporaryArtifacts" in source
    assert "[AllowNull()]" in source
    assert "[AllowEmptyCollection()]" in source
    assert "[string]::IsNullOrWhiteSpace([string]$candidate)" in source
    assert "[IO.Path]::GetDirectoryName($full).TrimEnd('\\')" in source
    assert "[string]::Equals($parent,$tempFull,[StringComparison]::OrdinalIgnoreCase)" in source
    assert "scan-[a-f0-9]{32}" in source
    assert "update-[a-f0-9]{32}-result" in source
    assert "action-[a-f0-9]{32}-(?:request|result)" in source
    assert "[IO.FileAttributes]::ReparsePoint" in source
    assert "Remove-Item -LiteralPath $full -Force -ErrorAction Stop" in source
    assert "Remove-NyxTemporaryArtifacts" in text(COMPOSITION)


def test_f009_ui_optional_cleanup_uses_helper_not_multi_literalpath() -> None:
    source = text(MAIN)
    assert "QA10-F-009" in source
    assert "Remove-NyxTemporaryArtifacts -Path @($req,$out)" in source
    assert "Remove-NyxTemporaryArtifacts -Path @($output)" in source
    assert "Remove-NyxTemporaryArtifacts -Path @($script:NyxUi.UpdateOutput)" in source
    assert "Remove-NyxTemporaryArtifacts -Path @($script:NyxUi.ScanOutput,$script:NyxUi.ProgressPath,$script:NyxUi.CancelPath)" in source
    assert "Remove-NyxTemporaryArtifacts -Path @($script:NyxUi.ScanOutput,$script:NyxUi.ProgressPath,$script:NyxUi.CancelPath,$script:NyxUi.UpdateOutput)" in source
    assert "Remove-Item -LiteralPath $req,$out" not in source
    assert "Remove-Item -LiteralPath $script:NyxUi.ScanOutput,$script:NyxUi.ProgressPath" not in source
    assert "Remove-Item -LiteralPath $script:NyxUi.UpdateOutput" not in source


def test_f009_acceptance_cleanup_uses_same_contract() -> None:
    source = text(APP)
    assert "Remove-NyxTemporaryArtifacts -Path @($out,$progress,$cancel)" in source
    assert "AcceptanceUiCloseProbe" in source
    assert "Show-NyxMainWindow -AcceptanceCloseProbe" in source
    assert "ProbeKind='UiClose'" in source
    assert "2026.09.26-eng-qa18" in source


def test_f009_windows_smoke_exercises_real_formclosing_and_boundary() -> None:
    source = text(SMOKE)
    for marker in (
        "F-009 optional temp cleanup accepts empty path fields without throwing",
        "F-009 optional temp cleanup deletes an allowed Nyx temp file",
        "F-009 optional temp cleanup rejects a lookalike path outside Nyx temp",
        "F-009 real UI close probe ({0}) exits cleanly",
        "F-009 real UI close probe ({0}) reports UiClose PASS",
        "updates disabled",
        "updates enabled before output exists",
    ):
        assert marker in source
    assert "-AcceptanceUiCloseProbe" in source
    assert "HarnessRevision='QA18-F015-PS51-18'" in source


def test_f009_full_native_close_matrix_remains_in_qa_plan() -> None:
    source = text(PLAN).lower()
    for marker in (
        "close immediately",
        "automatic update disabled",
        "before update output exists",
        "quick check",
        "cancel",
        "update-check",
        "close/relaunch",
        "unhandled .net",
        "terminal error",
        "background process",
        "outside the exact nyx temp root",
        "f-001 through f-009",
    ):
        assert marker in source
