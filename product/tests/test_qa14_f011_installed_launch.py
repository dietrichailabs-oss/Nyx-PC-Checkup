from __future__ import annotations

import json
import zipfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
NATIVE = ROOT / "native"
APP = ROOT / "src" / "app"
POWERSHELL = ROOT / "tests" / "powershell"
BUILD = "2026.10.02-eng-qa26"
HARNESS = "QA26-F023-PS51-26"


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def test_f011_native_launcher_suppresses_console_without_hiding_first_gui_window() -> None:
    launcher = text(NATIVE / "launcher.cpp")
    win_types = text(NATIVE / "win_types.hpp")

    assert "-NoLogo -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File" in launcher
    assert "-WindowStyle Hidden" not in launcher
    assert "nyx_run_gui_child_no_console(ps,cmd,root)" in launcher

    assert "nyx_run_process" in win_types
    assert "nyx_run_hidden_worker" in win_types
    assert "nyx_run_gui_child_no_console" in win_types
    assert "CREATE_NO_WINDOW,TRUE" in win_types
    assert "CREATE_NO_WINDOW,FALSE" in win_types
    assert "if(hideFirstWindow){si.dwFlags=STARTF_USESHOWWINDOW;si.wShowWindow=SW_HIDE;}" in win_types


def test_f011_hidden_worker_contract_remains_separate_for_setup_and_uninstall() -> None:
    installer = text(NATIVE / "installer.cpp")
    uninstaller = text(NATIVE / "uninstaller.cpp")
    assert "nyx_run_hidden_worker(ps,cmd,target)" in installer
    assert "nyx_run_hidden_worker(ps,cmd,safeCwd)" in uninstaller
    assert "nyx_run_gui_child_no_console" not in installer
    assert "nyx_run_gui_child_no_console" not in uninstaller


def test_f011_main_form_is_explicitly_normal_and_taskbar_visible() -> None:
    source = text(APP / "ui" / "MainWindow.psm1")
    assert "$form.ShowInTaskbar=$true" in source
    assert "$form.WindowState=[Windows.Forms.FormWindowState]::Normal" in source
    assert "$script:NyxUi.Form.ShowInTaskbar=$true" in source
    assert "$script:NyxUi.Form.Activate()" in source
    assert "$script:NyxUi.Form.BringToFront()" in source
    assert "TopMost=$true" not in source


def test_f011_singleton_protection_is_preserved() -> None:
    source = text(APP / "NyxPCCheckup.ps1")
    assert "Local\\DietrichAI.NyxPCCheckup.v1" in source
    assert "Nyx PC Checkup is already open for this Windows user." in source
    assert "[Threading.Mutex]::new" in source


def test_f011_windows_harness_exercises_actual_installed_entrypoints() -> None:
    source = text(POWERSHELL / "Run-WindowsInstalledLaunchRegression.ps1")
    for token in (
        "$script:ExpectedBuild='2026.10.02-eng-qa26'",
        "$script:ExpectedHarnessRevision='QA26-F023-PS51-26'",
        "Nyx PC Checkup.lnk",
        "CreateShortcut($desktopShortcut)",
        "Desktop shortcut target is exact installed launcher",
        "Desktop shortcut working directory is exact install root",
        "Desktop shortcut produces a visible Nyx main window",
        "Desktop shortcut main window is taskbar-eligible",
        "Second installed launch displays visible singleton warning",
        "Closing shortcut main window leaves no exact Nyx process",
        "Direct installed EXE produces a visible Nyx main window",
        "Immediate fresh relaunch opens visibly again",
        "ScriptNoSta",
        "ScriptSta",
        "F011_desktop_shortcut_visible_main_window",
        "-DestructiveCleanVmAcknowledged",
    ):
        assert token in source
    assert "Start-Process -FilePath $desktopShortcut" in source
    assert "Start-Process -FilePath $launcherPath" in source
    assert "Get-CimInstance Win32_Process" in source
    assert "[NyxTopLevelWindows]::Snapshot()" in source
    assert "PostMessageW" in source


def test_f011_diagnostics_use_bounded_write_path_and_archive_evidence() -> None:
    source = text(POWERSHELL / "Run-WindowsInstalledLaunchRegression.ps1")
    assert "HarnessCorrectionRevision='QA15-F011-PATH-1'" in source
    assert "('NQ15F011_'+[guid]::NewGuid().ToString('N').Substring(0,8))" in source
    assert "-EvidenceDirectory $diagnosticWriteDirectory -Label 'F011FreshInstall'" in source
    assert "DiagnosticPath).Length -ge 220" in source
    assert "F011FreshInstall_setup_diagnostics.json" in source
    assert "ArchivedDiagnosticPath" in source
    assert "Remove-Item -LiteralPath $diagnosticWriteDirectory" in source
    assert "-EvidenceDirectory $evidenceDirectory -Label 'F011FreshInstall'" not in source


def test_f011_windows_orchestrator_manifest_binds_and_runs_new_gate() -> None:
    source = text(POWERSHELL / "RUN_QA15_WINDOWS_GATE.ps1")
    assert "Run-WindowsInstalledLaunchRegression.ps1" in source
    assert "Nyx_PC_Checkup_F011_Installed_Launch.json" in source
    assert "Invoke-ExactHarness -Name 'Run-WindowsInstalledLaunchRegression.ps1'" in source
    assert "$script:ExpectedBuild='2026.10.02-eng-qa26'" in source
    assert "$script:ExpectedHarnessRevision='QA26-F023-PS51-26'" in source


def test_f011_version_metadata_is_successor_identity() -> None:
    version = json.loads((ROOT / "VERSION.json").read_text(encoding="utf-8"))
    assert version["version"] == "1.0.0"
    assert version["build"] == BUILD


def test_f011_built_portable_launcher_contains_correct_process_contract() -> None:
    portable = ROOT / "dist" / "Nyx_PC_Checkup_1.0.0_Portable.zip"
    if not portable.exists():
        pytest.skip("Generated portable artifact is not present before the build gate.")
    with zipfile.ZipFile(portable) as archive:
        launcher_name = next(name for name in archive.namelist() if name.endswith("/Nyx PC Checkup.exe"))
        launcher = archive.read(launcher_name)
    assert "-NonInteractive -STA -ExecutionPolicy Bypass -File".encode("utf-16le") in launcher
    assert "-WindowStyle Hidden".encode("utf-16le") not in launcher
