# Immutable QA26 F-023 candidate

Source: 0303a78a06f67252c86634cd73f1e4bda32dd3cc
Build: 2026.10.02-eng-qa26
Harness: QA26-F023-PS51-26

Common result details and Storage largest-file actions share Enter/double-click
dispatch, validated row/Tag/lifetime checks, reentrancy prevention, and focus
restoration. Cleanup editing behavior is unchanged. QA25 bytes remain frozen.

Source gates: Python 224/224; structural lint 2/2. Native PS5.1 integration:
116/116, against the real registered handlers, with real modal closure and
observed action targets. This is not an installed UI acceptance verdict.

Draft failures are preserved under ../draft-regression. They include fixture
reflection/argument/event issues corrected before source freeze. Stale QA15
artifact and temp-directory failures were avoided using clean source exports.

Installed F-023 must run first, then the required F-022/F-020/F-015/F-008 and
Standard/Elevated/lifecycle/privacy gates. No native PASS or release approval
is claimed here. Independent QA owns classification.

Artifact sizes/hashes and source-tree identity are in QA26_CANDIDATE.json.
