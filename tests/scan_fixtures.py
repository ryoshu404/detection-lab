"""Fail the build if a committed fixture contains a sensitive shape the scrubber
missed — a real machine SID, routable public IP, or 12-digit account id."""

from __future__ import annotations

import ipaddress
import re
import sys
from pathlib import Path

FIXTURES = Path("tests/fixtures")

SID = re.compile(r"S-1-5-21-(?!0-0-0)\d+-\d+-\d+")
# not part of a longer hex/GUID run
ACCOUNT_ID = re.compile(r"(?<![0-9a-fA-F-])(?!0{12})\d{12}(?![0-9a-fA-F-])")
IPV4 = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")


def _is_sensitive_ip(s: str) -> bool:
    try:
        ip = ipaddress.ip_address(s)
    except ValueError:
        return False
    return ip.is_global and not ip.is_multicast


def scan() -> int:
    findings = []
    for path in FIXTURES.rglob("*"):
        if not path.is_file() or path.name == "labels.yml":
            continue
        text = path.read_text(errors="ignore")
        for label, pattern in (("machine SID", SID), ("AWS account id", ACCOUNT_ID)):
            findings += [f"{path}: possible {label}: {m.group(0)}" for m in pattern.finditer(text)]
        findings += [f"{path}: possible public IPv4: {m.group(0)}"
                     for m in IPV4.finditer(text) if _is_sensitive_ip(m.group(0))]

    if findings:
        print("Unscrubbed values in fixtures:")
        for f in findings:
            print(f"  {f}")
        return 1
    print("fixtures clean")
    return 0


if __name__ == "__main__":
    sys.exit(scan())
