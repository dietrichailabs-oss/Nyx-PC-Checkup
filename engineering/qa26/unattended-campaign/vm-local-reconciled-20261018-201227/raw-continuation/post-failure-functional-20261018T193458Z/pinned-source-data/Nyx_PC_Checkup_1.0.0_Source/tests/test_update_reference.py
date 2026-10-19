from __future__ import annotations

import json
import re
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from urllib.parse import urlsplit

import pytest

PRODUCT_ID = "nyx-pc-checkup"
CURRENT_VERSION = "1.0.0"
MANIFEST_URL = "https://www.dietrichailabs.com/updates/nyx-pc-checkup.json"


@dataclass(frozen=True)
class SemVer:
    major: int
    minor: int
    patch: int
    pre: tuple[str, ...]


def parse_semver(value: str) -> SemVer:
    match = re.fullmatch(
        r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?",
        value.strip(),
    )
    if not match:
        raise ValueError(value)
    pre = tuple(match.group(4).split(".")) if match.group(4) else ()
    if any(x.isdigit() and len(x) > 1 and x.startswith("0") for x in pre):
        raise ValueError(value)
    return SemVer(int(match.group(1)), int(match.group(2)), int(match.group(3)), pre)


def compare_versions(left: str, right: str) -> int:
    a, b = parse_semver(left), parse_semver(right)
    for av, bv in zip((a.major, a.minor, a.patch), (b.major, b.minor, b.patch)):
        if av != bv:
            return -1 if av < bv else 1
    if not a.pre and not b.pre:
        return 0
    if not a.pre:
        return 1
    if not b.pre:
        return -1
    for av, bv in zip(a.pre, b.pre):
        if av == bv:
            continue
        an, bn = av.isdigit(), bv.isdigit()
        if an and bn:
            return -1 if int(av) < int(bv) else 1
        if an != bn:
            return -1 if an else 1
        return -1 if av < bv else 1
    return (len(a.pre) > len(b.pre)) - (len(a.pre) < len(b.pre))


def auto_due(enabled: bool, last: datetime | None, now: datetime) -> bool:
    return enabled and (last is None or now >= last + timedelta(days=7))


def allowed_url(value: str, purpose: str) -> bool:
    try:
        u = urlsplit(value)
    except ValueError:
        return False
    if u.scheme != "https" or u.hostname != "www.dietrichailabs.com" or u.username or u.password or u.fragment or u.query:
        return False
    if u.port not in (None, 443):
        return False
    if purpose == "manifest":
        return value == MANIFEST_URL
    path = u.path.rstrip("/")
    if purpose == "release":
        return path.lower() == "/apps/nyx-pc-checkup"
    if purpose == "download":
        return path.lower() == "/downloads" or u.path.lower().startswith("/downloads/")
    return False


def validate_manifest_bytes(data: bytes, *, maximum: int = 65536) -> dict[str, object]:
    if not data or len(data) > maximum:
        raise ValueError("size")
    obj = json.loads(data.decode("utf-8"))
    if not isinstance(obj, dict):
        raise ValueError("root")
    required = {"schema_version", "product", "latest_version", "release_name", "published_at", "release_url", "download_url"}
    if not required <= obj.keys():
        raise ValueError("required")
    if type(obj["schema_version"]) is not int or obj["schema_version"] != 1:
        raise ValueError("schema")
    if obj["product"] != PRODUCT_ID:
        raise ValueError("product")
    parse_semver(str(obj["latest_version"]))
    if not allowed_url(str(obj["release_url"]), "release") or not allowed_url(str(obj["download_url"]), "download"):
        raise ValueError("url")
    return obj


@pytest.mark.parametrize(
    ("left", "right", "expected"),
    [
        ("1.0.0", "1.0.0", 0),
        ("1.0.0", "1.0.1", -1),
        ("1.0.0", "1.1.0", -1),
        ("1.0.0", "2.0.0", -1),
        ("1.10.0", "1.9.0", 1),
        ("1.7.0", "1.6.2", 1),
        ("1.8.0-beta", "1.8.0", -1),
        ("1.8.0-beta.2", "1.8.0-beta.10", -1),
        ("1.0.0-rc.8", "1.0.0-rc.9", -1),
        ("1.0.0+build.1", "1.0.0+build.2", 0),
    ],
)
def test_semver_reference_matrix(left: str, right: str, expected: int) -> None:
    assert compare_versions(left, right) == expected


@pytest.mark.parametrize("value", ["", "1", "1.2", "01.2.3", "1.02.3", "1.2.03", "1.0.0-beta.01", "v1.0.0", "1.0.0-"])
def test_malformed_versions_are_rejected(value: str) -> None:
    with pytest.raises(ValueError):
        parse_semver(value)


def test_first_automatic_check_occurs() -> None:
    now = datetime(2026, 8, 23, tzinfo=timezone.utc)
    assert auto_due(True, None, now)


def test_second_automatic_check_within_seven_days_is_suppressed() -> None:
    now = datetime(2026, 8, 23, tzinfo=timezone.utc)
    assert not auto_due(True, now - timedelta(days=6, hours=23, minutes=59), now)


def test_automatic_check_at_seven_days_occurs() -> None:
    now = datetime(2026, 8, 23, tzinfo=timezone.utc)
    assert auto_due(True, now - timedelta(days=7), now)


def test_disabled_automatic_check_is_respected() -> None:
    assert not auto_due(False, None, datetime.now(timezone.utc))


def test_manual_check_contract_bypasses_schedule() -> None:
    # Production Invoke-NyxUpdateCheck gates only when -not $Manual.
    from pathlib import Path

    root = Path(__file__).resolve().parents[1]
    source = (root / "src/app/updates/UpdateChecker.psm1").read_text(encoding="utf-8")
    assert "if(-not $Manual)" in source
    assert "Test-NyxAutomaticUpdateCheckDue" in source


def valid_manifest() -> dict[str, object]:
    return {
        "schema_version": 1,
        "product": PRODUCT_ID,
        "latest_version": "1.0.1",
        "release_name": "Nyx PC Checkup 1.0.1",
        "release_channel": "stable",
        "published_at": "2026-08-23T00:00:00Z",
        "release_url": "https://www.dietrichailabs.com/apps/nyx-pc-checkup/",
        "download_url": "https://www.dietrichailabs.com/downloads/",
        "sha256": "A" * 64,
        "message": "A new version of Nyx PC Checkup is available.",
    }


def test_valid_manifest_is_accepted_and_unknown_fields_are_ignored() -> None:
    value = valid_manifest()
    value["future_field"] = {"ignored": True}
    assert validate_manifest_bytes(json.dumps(value).encode())["latest_version"] == "1.0.1"


def test_wrong_product_is_rejected() -> None:
    value = valid_manifest()
    value["product"] = "rangescout"
    with pytest.raises(ValueError, match="product"):
        validate_manifest_bytes(json.dumps(value).encode())


def test_unsupported_schema_is_rejected() -> None:
    value = valid_manifest()
    value["schema_version"] = 2
    with pytest.raises(ValueError, match="schema"):
        validate_manifest_bytes(json.dumps(value).encode())




@pytest.mark.parametrize("invalid_schema", [True, False, "1", 1.0, None])
def test_schema_version_requires_exact_json_integer(invalid_schema: object) -> None:
    value = valid_manifest()
    value["schema_version"] = invalid_schema
    with pytest.raises(ValueError, match="schema"):
        validate_manifest_bytes(json.dumps(value).encode())


def test_missing_required_field_is_rejected() -> None:
    value = valid_manifest()
    del value["download_url"]
    with pytest.raises(ValueError, match="required"):
        validate_manifest_bytes(json.dumps(value).encode())


def test_invalid_json_is_rejected() -> None:
    with pytest.raises(json.JSONDecodeError):
        validate_manifest_bytes(b"{not json")


def test_oversized_response_is_rejected() -> None:
    with pytest.raises(ValueError, match="size"):
        validate_manifest_bytes(b"x" * 65537)


@pytest.mark.parametrize(
    ("url", "purpose"),
    [
        ("http://www.dietrichailabs.com/apps/nyx-pc-checkup/", "release"),
        ("https://dietrichailabs.com/apps/nyx-pc-checkup/", "release"),
        ("https://evil.example/apps/nyx-pc-checkup/", "release"),
        ("https://www.dietrichailabs.com:444/apps/nyx-pc-checkup/", "release"),
        ("https://user@www.dietrichailabs.com/apps/nyx-pc-checkup/", "release"),
        ("https://www.dietrichailabs.com/apps/other/", "release"),
        ("https://www.dietrichailabs.com/downloads/?file=x", "download"),
        ("https://www.dietrichailabs.com/updates/other.json", "manifest"),
    ],
)
def test_invalid_or_unapproved_urls_are_rejected(url: str, purpose: str) -> None:
    assert not allowed_url(url, purpose)


def test_downgrade_is_not_offered() -> None:
    assert compare_versions(CURRENT_VERSION, "0.9.9") > 0


def test_update_available_is_only_when_server_version_is_newer() -> None:
    assert compare_versions(CURRENT_VERSION, "1.0.1") < 0
    assert compare_versions(CURRENT_VERSION, "1.0.0") == 0
    assert compare_versions(CURRENT_VERSION, "0.9.9") > 0
