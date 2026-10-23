#!/usr/bin/env python3
"""Build immutable QA27 artifacts without running acceptance/regression suites.

The native F-024 gate must be executed before any other successor regression.
This entry point calls the existing deterministic package/compiler primitives;
it never installs a candidate, launches product/scripts, or changes policy.
"""
from __future__ import annotations

import json
from pathlib import Path

import build_release as br


def main() -> None:
    if br.BUILD_ID != '2026.10.19-eng-qa27' or br.HARNESS_REVISION != 'QA27-F024-PS51-27':
        raise br.BuildError('Unexpected QA27 source identity')
    if br.DIST.exists():
        raise br.BuildError('Refuse to overwrite an existing candidate; use a new clean source root')
    br.remove_python_caches(br.ROOT)
    pe = br.build_launchers()
    payload = br.stage_portable()
    portable, source, identity = br.build_archives()
    pe.append(br.build_setup())
    artifacts = {}
    for key, path in [('setup', br.DIST / 'Nyx_PC_Checkup_1.0.0_Setup.exe'), ('portable', portable), ('source', source)]:
        artifacts[key] = {'path': str(path), 'bytes': path.stat().st_size, 'sha256': br.sha256(path)}
    br.atomic_json(br.DIST / 'QA27_CANDIDATE.json', {
        'build': br.BUILD_ID,
        'harness': br.HARNESS_REVISION,
        'artifacts': artifacts,
        'sourceTreeSha256': identity['treeSha256'],
        'sourceFiles': identity['fileCount'],
        'payloadManifestSha256': br.sha256(br.STAGE / 'PAYLOAD_MANIFEST.json'),
        'nativePeInspection': pe,
        'regressionSuitesExecuted': 0,
        'focusedF024': 'NOT_RUN_NATIVE_PS51_GATE_REQUIRED_FIRST',
        'releaseAuthorization': False,
    })
    print(json.dumps({'artifacts': artifacts, 'sourceTreeSha256': identity['treeSha256']}, indent=2))


if __name__ == '__main__':
    main()
