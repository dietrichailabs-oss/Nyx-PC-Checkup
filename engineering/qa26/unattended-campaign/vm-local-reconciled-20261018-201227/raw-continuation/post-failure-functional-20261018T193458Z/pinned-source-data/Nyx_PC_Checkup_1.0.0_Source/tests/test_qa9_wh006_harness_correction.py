from __future__ import annotations
import hashlib
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MIG=ROOT/"tests/powershell/Run-WindowsQA2MigrationRegression.ps1"

def sha(path: Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

def test_wh006_correction_is_carried_forward_into_qa10_source():
    text=MIG.read_text(encoding="utf-8-sig")
    assert "HarnessCorrectionRevision='QA9-WH006-1'" in text
    assert "ResetRuns=@($script:ResetRuns.ToArray())" in text
    assert "elseif($exit -eq 6)" in text

