from __future__ import annotations

import ipaddress
import re
from collections.abc import Mapping, Sequence
from pathlib import Path

SENSITIVE = {
    "password",
    "passwd",
    "pwd",
    "token",
    "accesstoken",
    "refreshtoken",
    "authtoken",
    "sessiontoken",
    "idtoken",
    "apikey",
    "accesskey",
    "secret",
    "secretkey",
    "clientsecret",
    "authorization",
    "authheader",
    "bearertoken",
    "cookie",
    "setcookie",
    "credential",
    "credentials",
    "privatekey",
    "connectionstring",
    "protectedstate",
}


def normalized_key(value: object) -> str:
    return re.sub(r"[^A-Za-z0-9]", "", str(value)).lower()


def sanitize(value: object) -> object:
    if isinstance(value, Mapping):
        return {k: "[REDACTED]" if normalized_key(k) in SENSITIVE else sanitize(v) for k, v in value.items()}
    if isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
        return [sanitize(v) for v in value]
    if isinstance(value, str):
        tokens = re.findall(r"(?<![A-Za-z0-9])[A-Fa-f0-9:.]{2,45}(?![A-Za-z0-9])", value)
        for token in sorted(tokens, key=len, reverse=True):
            try:
                ipaddress.ip_address(token)
            except ValueError:
                continue
            value = value.replace(token, "[IP REDACTED]")
        value = re.sub(r"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]+", "Bearer [REDACTED]", value)
        value = re.sub(r"(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", "[EMAIL REDACTED]", value)
        return value
    return value


def test_nested_secret_roles_are_redacted_before_serialization() -> None:
    source = {
        "safe": "visible",
        "Password": "my secret phrase",
        "nested": {
            "token": "abc123",
            "Authorization": "Bearer xyz.123",
            "connection_string": "server=x;password=y",
            "items": [{"api-key": "k"}, {"note": "keep"}],
        },
    }
    result = sanitize(source)
    assert result["safe"] == "visible"
    assert result["Password"] == "[REDACTED]"
    assert result["nested"]["token"] == "[REDACTED]"
    assert result["nested"]["Authorization"] == "[REDACTED]"
    assert result["nested"]["connection_string"] == "[REDACTED]"
    assert result["nested"]["items"][0]["api-key"] == "[REDACTED]"


def test_ipv4_and_compressed_expanded_and_mapped_ipv6_are_redacted() -> None:
    value = "v4=192.168.1.9 loop=::1 compressed=2001:db8::1 expanded=2001:0db8:0000:0000:0000:ff00:0042:8329 mapped=::ffff:192.0.2.128"
    result = sanitize(value)
    for address in ["192.168.1.9", "::1", "2001:db8::1", "2001:0db8:0000:0000:0000:ff00:0042:8329", "::ffff:192.0.2.128"]:
        assert address not in result
    assert result.count("[IP REDACTED]") >= 5


def test_bearer_and_email_are_redacted() -> None:
    result = sanitize("Authorization: Bearer abc.def-123 email=a@example.com")
    assert "abc.def-123" not in result
    assert "a@example.com" not in result


def test_production_privacy_module_contains_same_required_roles_and_parser() -> None:
    root = Path(__file__).resolve().parents[1]
    source = (root / "src/app/core/Privacy.psm1").read_text(encoding="utf-8").lower()
    for role in SENSITIVE:
        assert role in source
    assert "ipaddress]::tryparse" in source
    assert "convertto-nyxprivatevalue" in source
