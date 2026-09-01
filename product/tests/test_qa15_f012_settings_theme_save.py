from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "src" / "app" / "ui" / "MainWindow.psm1"


def function_body(source: str, name: str) -> str:
    match = re.search(rf"(?ms)^function {re.escape(name)}\s*\{{.*?(?=^function |\Z)", source)
    assert match, f"missing {name}"
    return match.group(0)


def settings_source() -> str:
    return function_body(MAIN.read_text(encoding="utf-8-sig"), "Show-NyxSettingsPage")


def save_handler(source: str) -> str:
    match = re.search(r"(?ms)\$save\.Add_Click\(\{(.*?)\}\)\s*\n\s*\$card\.Controls\.Add\(\$save\)", source)
    assert match, "missing Save settings click handler"
    return match.group(1)


def test_f012_deferred_save_uses_sender_owned_stable_control_state() -> None:
    source = settings_source()
    handler = save_handler(source)
    for token in (
        "$settingsState=[pscustomobject][ordered]@{",
        "Configuration=$config",
        "ThemeControl=$theme",
        "NotificationControl=$notify",
        "AutomaticUpdatesControl=$autoUpdates",
        "$save.Tag=$settingsState",
        "param($sender,$eventArgs)",
        "$state=$sender.Tag",
    ):
        assert token in source
    assert "$theme.SelectedItem" not in handler
    assert "$notify.Checked" not in handler
    assert "$autoUpdates.Checked" not in handler
    assert "$config.theme" not in handler


def test_f012_save_validates_and_persists_all_settings_before_success() -> None:
    handler = save_handler(settings_source())
    for token in (
        "$selectedTheme=[string]$state.ThemeControl.SelectedItem",
        "$selectedTheme -notin @('FollowWindows','Dark','Light')",
        "$state.Configuration.theme=$selectedTheme",
        "$state.Configuration.notificationsEnabled=[bool]$state.NotificationControl.Checked",
        "$state.Configuration.updates.enabled=[bool]$state.AutomaticUpdatesControl.Checked",
        "Save-NyxConfiguration -Configuration $state.Configuration",
    ):
        assert token in handler
    save_index = handler.index("Save-NyxConfiguration")
    success_index = handler.index("Settings were saved.")
    assert save_index < success_index
    assert "catch{" not in handler
    assert "Set-StrictMode" not in handler


def test_f012_theme_matrix_remains_complete_and_initial_selection_is_repaired_config() -> None:
    source = settings_source()
    assert "$theme.Items.AddRange(@('FollowWindows','Dark','Light'))" in source
    assert "$theme.SelectedItem=[string]$config.theme" in source
