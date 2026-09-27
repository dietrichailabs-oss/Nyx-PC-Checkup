from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "src" / "app" / "ui" / "MainWindow.psm1"
CONTROLS = ROOT / "src" / "app" / "ui" / "Controls.psm1"
ROUTING = ROOT / "docs" / "WHO_GETS_WHAT_NEXT.md"
PLAN = ROOT / "docs" / "QA_TEST_PLAN.md"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def function_body(source: str, name: str) -> str:
    match = re.search(rf"(?ms)^function {re.escape(name)}\s*\{{.*?(?=^function |\Z)", source)
    assert match, f"missing {name}"
    return match.group(0)


def test_qa9_f008_global_layout_no_longer_uses_pre_layout_right_anchors() -> None:
    source = read(MAIN)
    main = function_body(source, "Show-NyxMainWindow")
    assert "Get-NyxResponsiveWindowSize -Form $form" in main
    assert "$headerActions.Dock='Right'" in main
    assert "$footerActions.Dock='Bottom'" in main
    assert "$rail.AutoScroll=$true" in main
    assert "$version.Location=New-Object Drawing.Point(0,($y+8))" in main
    assert "$export.Anchor='Top,Right'" not in main
    assert "$progress.Anchor='Top,Right'" not in main
    assert "$cancel.Anchor='Top,Right'" not in main
    assert "$form.Add_ResizeEnd" in main


def test_qa9_f008_page_width_can_contract_and_long_labels_wrap() -> None:
    main = read(MAIN)
    controls = read(CONTROLS)
    assert "Get-NyxPageWidth { return [math]::Max(430," in main
    assert "$label.AutoEllipsis=$false" in controls
    assert "$label.UseCompatibleTextRendering=$true" in controls
    assert "$grid.ShowCellToolTips=$true" in controls
    assert "Register-NyxFocusScrollTree -Root $script:NyxUi.Content" in main
    assert "ScrollControlIntoView($target)" in main


def test_qa9_f008_startup_primary_actions_are_above_grid() -> None:
    source = function_body(read(MAIN), "Show-NyxStartupPage")
    positions = {}
    for label, var in [
        ("refresh", "$refresh"),
        ("disable", "$disable"),
        ("enable", "$enable"),
        ("location", "$location"),
        ("grid", "$grid"),
    ]:
        match = re.search(rf"{re.escape(var)}=.*?-Y\s+(\d+)", source)
        assert match, label
        positions[label] = int(match.group(1))
    assert max(positions[k] for k in ("refresh", "disable", "enable", "location")) < positions["grid"]
    assert "$grid.AutoSizeColumnsMode='None'" in source
    assert "$grid.ScrollBars='Both'" in source
    for column in ("State", "Name", "Publisher", "Source", "Control", "Exists", "Impact"):
        assert f"$grid.Columns['{column}'].Width=" in source


def test_qa9_f008_apps_actions_are_visible_before_grid() -> None:
    source = function_body(read(MAIN), "Show-NyxAppsPage")
    for token in [
        "$open=New-NyxButton -Text 'Open Installed Apps'",
        "$full=New-NyxButton -Text 'Run Full Check'",
        "$folder=New-NyxButton -Text 'Open selected folder'",
        "$folder.Enabled=$false",
        "$grid=New-NyxGrid -X 24 -Y 208",
    ]:
        assert token in source
    for name in ("$open", "$full", "$folder"):
        match = re.search(rf"{re.escape(name)}=.*?-Y\s+(\d+)", source)
        assert match and int(match.group(1)) < 208


def test_qa9_f008_settings_controls_have_non_truncating_widths() -> None:
    source = function_body(read(MAIN), "Show-NyxSettingsPage")
    assert "$notify.Size=New-Object Drawing.Size($inner,38)" in source
    assert "$autoUpdates.Size=New-Object Drawing.Size($inner,38)" in source
    assert "-Text 'Check for Updates Now' -X 22 -Y 326 -Width 255" in source
    assert "-Text 'Open local data folder' -X 22 -Y 420 -Width 235" in source
    assert "-Text 'Delete local logs' -X 271 -Y 420 -Width 205" in source
    assert "-Text 'Save settings' -X 22 -Y 466 -Width 180" in source
    assert "Set-NyxPageScrollExtent -Height 910" in source


def test_qa9_f008_cleanup_action_is_brought_inside_constrained_initial_view() -> None:
    source = function_body(read(MAIN), "Show-NyxCleanupPage")
    assert "$grid=New-NyxGrid -X 24 -Y 174" in source
    assert "-Height 326" in source
    assert "-Text 'Review and clean selected' -X 24 -Y 556" in source
    assert "Set-NyxPageScrollExtent -Height 660" in source


def test_qa10_final_ui_matrix_is_explicitly_required() -> None:
    plan = read(PLAN)
    for token in [
        "100%",
        "125%",
        "150%",
        "200%",
        "1366",
        "768",
        "Dark",
        "Light",
        "Follow Windows",
        "keyboard",
        "focus",
        "Export report",
        "Cancel scan",
    ]:
        assert token.lower() in plan.lower()


def test_current_cycle_routing_stays_engineering_to_independent_qa_only() -> None:
    routing = read(ROUTING)
    assert "Engineering" in routing
    assert "Independent QA" in routing
    assert "No additional reviewer, gate, recipient, or blocker is designated" in routing
