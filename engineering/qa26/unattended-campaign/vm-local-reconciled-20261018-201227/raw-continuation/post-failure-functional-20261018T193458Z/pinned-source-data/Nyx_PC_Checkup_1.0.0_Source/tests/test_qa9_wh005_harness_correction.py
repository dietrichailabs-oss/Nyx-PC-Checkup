from __future__ import annotations
import hashlib
import re
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MIG=ROOT/"tests/powershell/Run-WindowsQA2MigrationRegression.ps1"

def sha(path: Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

def test_wh005_correction_is_carried_forward_into_qa10_source():
    text=MIG.read_text(encoding="utf-8-sig")
    assert "CallerVisibilityRequiredForFixtureCreation=$false" in text
    assert "function Get-QA2HarnessPathMap" in text
    assert "function Initialize-QA2HarnessDataDirectories" in text

