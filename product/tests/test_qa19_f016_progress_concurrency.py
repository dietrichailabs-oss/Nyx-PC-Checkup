from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKER = (ROOT / 'src/app/workers/ScanWorker.ps1').read_text(encoding='utf-8-sig')
UI = (ROOT / 'src/app/ui/MainWindow.psm1').read_text(encoding='utf-8-sig')


def test_progress_writer_shares_and_bounds_only_lock_retries():
    writer = WORKER.split('function Write-NyxProgressEvent {', 1)[1].split('$started=', 1)[0]
    assert '[IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete' in writer
    assert '$attempt -lt 5' in writer
    assert '$code -notin @(32,33)' in writer and '{throw}' in writer
    assert 'Add-Content' not in writer
    assert '$stream.Dispose()' in writer


def test_reader_keeps_partial_tail_for_next_poll():
    assert 'Read-NyxCompleteProgressLines -Path $script:NyxUi.ProgressPath' in UI
    assert '$text.LastIndexOf("`n")' in UI
    assert '$text.Substring(0,$last)' in UI
    assert '[IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete' in UI


def test_original_worker_error_survives_secondary_telemetry_failure():
    assert '$workerError=$_.Exception.Message' in WORKER
    assert 'WorkerError=$workerError' in WORKER
    assert "-Type 'Failed'" in WORKER and 'Error=$workerError' in WORKER
    assert 'original worker error: {0}' in WORKER
    assert 'exit 1' in WORKER
    assert 'Save-NyxScanResults -Scan $scan' in WORKER
    assert 'Set-StrictMode -Version 2.0' in WORKER


def test_deterministic_native_contention_probe_is_shipped():
    probe = (ROOT / 'tests/powershell/Test-QA19ProgressConcurrency.ps1').read_text(encoding='utf-8-sig')
    assert 'FileShare.None' in probe
    assert 'Bounded retry succeeds' in probe
    assert 'Non-sharing I/O errors are not suppressed' in probe
