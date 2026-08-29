# Build and Reproduce — Nyx PC Checkup 1.0.0 QA7

## Prerequisites

- Python 3.11 or later
- `pytest`
- LLVM/Clang `clang++` and `lld-link` capable of targeting `x86_64-pc-windows-msvc`
- Repository-provided minimal Windows import definitions

Set `NYX_CLANG` or `NYX_LLD_LINK` only when the tools are not on `PATH`. The build uses no GitHub or network dependency. The application runtime relies on Windows PowerShell 5.1 and Windows/.NET components already present on supported Windows.

## Preferred build

From the exact source root:

```text
python3 tools/build_and_verify_reproduction.py
```

The wrapper:

1. cleans build/release/handoff staging;
2. compiles native x64 launcher, uninstaller, and setup with embedded `asInvoker` manifests;
3. allowlist-stages the runtime;
4. creates and validates `PAYLOAD_MANIFEST.json`;
5. builds deterministic Portable and Source ZIPs;
6. runs structural lint, QA5 parser/automatic-variable regression gates, generic-list compatibility gates, and the full Python contract/safety/package suite;
7. extracts the generated Source ZIP into a new temporary root;
8. independently rebuilds it;
9. requires exact Setup, Portable, and Source SHA-256 matches;
10. records reproducibility evidence;
11. rebuilds and internally audits one immutable QA7 master handoff ZIP.

Direct verification:

```text
python3 tools/ps_lint.py src/app
python3 tools/ps_lint.py tests/powershell
python3 -m pytest -q
```

Four archive/PE tests are skipped only before generated artifacts exist. The documented wrapper builds first and requires the complete suite to pass.

## Determinism and identity

ZIP entries are sorted with fixed timestamps. JSON output is normalized. Source identity excludes only its own `SOURCE_TREE_IDENTITY.json` and non-source build/evidence directories to avoid circular or machine-specific identity. The raw QA5 evidence directory is intentionally excluded from the distributable source tree but is copied into the primary QA7 handoff when its exact recorded identity is present.

The master handoff includes session timing evidence, so separate handoff sessions need not be byte-identical. Each must pass its own `MASTER_MANIFEST.json` and `SHA256SUMS.txt` audit.

Never edit a generated candidate in place. Any changed byte requires a new build identity, manifests, hashes, and applicable retesting.

## Windows verification

Extract the exact master handoff on disposable Windows 10/11 x64 snapshots and invoke:

```text
RUN_QA11_WINDOWS_GATE.ps1 -Phase Smoke
RUN_QA11_WINDOWS_GATE.ps1 -Phase Standard -DestructiveCleanVmAcknowledged
RUN_QA11_WINDOWS_GATE.ps1 -Phase Elevated -DestructiveCleanVmAcknowledged
```

Use `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`, not PowerShell 7. Standard and Elevated phases require separate appropriate snapshots. Preserve the generated phase evidence ZIPs and exact outer-delivery hash.

Every mandatory harness report must contain `HarnessRevision='QA11-F010-PS51-9'`.
