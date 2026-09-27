from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "src" / "app"
WINDOWS_HARNESSES = ROOT / "tests" / "powershell"


def powershell_files() -> list[Path]:
    return sorted(
        [
            *APP.rglob("*.ps1"),
            *APP.rglob("*.psm1"),
            *WINDOWS_HARNESSES.rglob("*.ps1"),
        ]
    )


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_legacy_new_object_generic_list_construction_is_absent() -> None:
    pattern = re.compile(
        r"New-Object\s+System\.Collections\.Generic\.List\[",
        re.IGNORECASE,
    )
    findings: list[str] = []
    for path in powershell_files():
        for line_number, line in enumerate(read(path).splitlines(), 1):
            if pattern.search(line):
                findings.append(f"{path.relative_to(ROOT)}:{line_number}:{line.strip()}")
    assert not findings, "\n".join(findings)


def test_generic_lists_are_materialized_before_array_subexpression() -> None:
    assignment = re.compile(
        r"\$(?P<variable>(?:script:)?[A-Za-z_][\w:]*)\s*=\s*"
        r"\[System\.Collections\.Generic\.List\[[^\]\r\n]+\]\]::new\(\)",
        re.IGNORECASE,
    )
    findings: list[str] = []
    for path in powershell_files():
        source = read(path)
        variables = {match.group("variable") for match in assignment.finditer(source)}
        for variable in variables:
            unsafe = re.compile(
                r"@\(\s*\$" + re.escape(variable) + r"\s*\)",
                re.IGNORECASE,
            )
            for match in unsafe.finditer(source):
                line_number = source.count("\n", 0, match.start()) + 1
                findings.append(
                    f"{path.relative_to(ROOT)}:{line_number}:{match.group(0)}"
                )
    assert not findings, "\n".join(findings)


def test_required_windows_harnesses_pin_windows_powershell_51() -> None:
    expected = (
        "$PSVersionTable.PSEdition -ne 'Desktop'"
        " -or $PSVersionTable.PSVersion.Major -ne 5"
        " -or $PSVersionTable.PSVersion.Minor -ne 1"
    )
    names = {
        "Run-WindowsSmokeTests.ps1",
        "Run-WindowsElevatedStartupRollback.ps1",
        "Run-WindowsQA2MigrationRegression.ps1",
        "Run-WindowsInstallerLifecycle.ps1",
        "Run-WindowsInstalledLaunchRegression.ps1",
    }
    actual = {path.name for path in WINDOWS_HARNESSES.glob("*.ps1")}
    assert names <= actual
    assert "RUN_QA15_WINDOWS_GATE.ps1" in actual
    for name in sorted(names):
        source = read(WINDOWS_HARNESSES / name)
        assert expected in source
        assert "HarnessRevision='QA21-F018-PS51-21'" in source
    runner = read(WINDOWS_HARNESSES / "RUN_QA15_WINDOWS_GATE.ps1")
    assert expected in runner
    assert "$script:ExpectedHarnessRevision='QA21-F018-PS51-21'" in runner
    assert "$ErrorActionPreference='Continue'" in runner
    assert "QA15_WINDOWS_PARSE_PREFLIGHT.json" in runner
    assert "Parser]::ParseFile" in runner
    assert "ExpectedReportPath" in runner
    assert "ReportValidationError" in runner
    assert "Harness report verdict is FAIL" in runner
    assert "QA15_WINDOWS_RUN_SUMMARY.json" in runner


def test_required_harness_report_collections_use_to_array() -> None:
    expected_tokens = {
        "Run-WindowsSmokeTests.ps1": "Results=@($script:Results.ToArray())",
        "Run-WindowsElevatedStartupRollback.ps1": "Results=@($script:Results.ToArray())",
        "Run-WindowsQA2MigrationRegression.ps1": "Results=@($script:Results.ToArray())",
        "Run-WindowsInstallerLifecycle.ps1": "Results=@($results.ToArray())",
        "Run-WindowsInstalledLaunchRegression.ps1": "Results=@($script:Results.ToArray())",
    }
    for name, token in expected_tokens.items():
        source = read(WINDOWS_HARNESSES / name)
        assert token in source
    installer = read(WINDOWS_HARNESSES / "Run-WindowsInstallerLifecycle.ps1")
    assert "return @($fail.ToArray())" in installer


def test_generic_list_values_stored_in_maps_are_materialized() -> None:
    downloads = read(APP / "checks" / "DownloadsAnalysis.psm1")
    assert "Files=@($map[$key].ToArray())" in downloads
    assert "Files=@($map[$key])" not in downloads


def test_harness_generic_lists_are_materialized_before_json_serialization() -> None:
    smoke = read(WINDOWS_HARNESSES / "Run-WindowsSmokeTests.ps1")
    elevated = read(WINDOWS_HARNESSES / "Run-WindowsElevatedStartupRollback.ps1")
    assert "$result.ToArray()|ConvertTo-Json" in smoke
    assert "$parseErrors.ToArray()|ConvertTo-Json" in smoke
    assert "$records.ToArray()|ConvertTo-Json" in elevated
