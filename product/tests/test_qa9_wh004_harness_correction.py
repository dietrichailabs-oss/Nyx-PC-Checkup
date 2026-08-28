from __future__ import annotations
import hashlib
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MIG=ROOT/"tests/powershell/Run-WindowsQA2MigrationRegression.ps1"

def sha(path: Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

def test_wh004_correction_is_carried_forward_into_qa10_source():
    text=MIG.read_text(encoding="utf-8-sig")
    assert "HarnessCorrectionHistory=@('QA9-WH004-1','QA9-WH005-1','QA9-WH006-1')" in text
    assert "Get-NyxStartupApplications" not in text
    assert "Disable-NyxStartupApplication" not in text

