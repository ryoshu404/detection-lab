"""Capture a detonation window from Elastic into a scrubbed CI fixture.

Runs locally since git history is permanent. Two passes: exact-match from
the environment for the genuinely sensitive values (SCRUB_AWS_ID,
SCRUB_HOME_IP), and pattern normalization of lab identifiers (SIDs,
private IPs, hostnames) for presentation.
"""

from __future__ import annotations

import getpass
import json
import os
import re
import sys
from pathlib import Path

import requests

ES_URL = os.environ.get("ES_URL")

# Normalized for presentation
SHAPE_RULES: list[tuple[re.Pattern, str]] = [
    (re.compile(r"S-1-5-21(?:-\d+){3,4}"), "S-1-5-21-0-0-0-0"),
    (re.compile(r"\b10(?:\.\d{1,3}){3}\b"), "10.0.0.0"),
    (re.compile(r"\b192\.168(?:\.\d{1,3}){2}\b"), "192.168.0.0"),
    (re.compile(r"\b172\.(?:1[6-9]|2\d|3[01])(?:\.\d{1,3}){2}\b"), "172.16.0.0"),
    (re.compile(r"\b(win-endpoint|linux-endpoint|macos-endpoint|pve2?|elastic|fleet|ghosts|sensor|builder)\b", re.I), "LAB-HOST"),
    (re.compile(r"\b(Administrator|jsmith|spoli|Tenebria)\b"), "LAB-USER"),
]


def _exact_rules() -> list[tuple[str, str]]:
    rules = []
    if os.environ.get("SCRUB_AWS_ID"):
        rules.append((os.environ["SCRUB_AWS_ID"], "000000000000"))
    if os.environ.get("SCRUB_HOME_IP"):
        rules.append((os.environ["SCRUB_HOME_IP"], "203.0.113.0"))
    return rules


def scrub(text: str) -> str:
    for literal, repl in _exact_rules():
        text = text.replace(literal, repl)
    for pattern, repl in SHAPE_RULES:
        text = pattern.sub(repl, text)
    return text


def _es_url() -> str:
    if ES_URL:
        return ES_URL.rstrip("/")
    return os.environ.get("KIBANA_URL", "").rstrip("/").replace(":5601", ":9200")


def _prompt_auth() -> tuple[str, str]:
    user = input("Elastic user [elastic]: ").strip() or "elastic"
    password = getpass.getpass("Elastic password: ")
    return user, password


def fetch_window(index, host, start, end, auth) -> list[dict]:
    body = {
        "size": 1000,
        "query": {"bool": {"filter": [
            {"term": {"host.name": host}},
            {"range": {"@timestamp": {"gte": start, "lte": end}}},
        ]}},
        "sort": [{"@timestamp": "asc"}],
    }
    resp = requests.get(f"{_es_url()}/{index}/_search",
                    auth=auth, headers={"Content-Type": "application/json"},
                    data=json.dumps(body), timeout=30, verify=False)
    if resp.status_code != 200:
        sys.exit(f"search failed [{resp.status_code}]: {resp.text}")
    return resp.json()["hits"]["hits"]


def fetch_mappings(index, auth) -> dict:
    resp = requests.get(f"{_es_url()}/{index}/_mapping", auth=auth, timeout=30, verify=False)
    if resp.status_code != 200:
        sys.exit(f"mapping fetch failed [{resp.status_code}]: {resp.text}")
    return resp.json()


def write_fixture(out_dir: Path, hits, mappings) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    # Keep _id so labels.yml can reference the true positives.
    lines = [scrub(json.dumps({"_id": h["_id"], "_source": h["_source"]})) for h in hits]
    (out_dir / "events.ndjson").write_text("\n".join(lines) + "\n")
    (out_dir / "mappings.json").write_text(scrub(json.dumps(mappings, indent=2)))
    print(f"wrote {len(hits)} events -> {out_dir/'events.ndjson'}")
    print("Next: write labels.yml naming the true-positive _id(s), and review the "
          "scrubbed output before committing.")


if __name__ == "__main__":
    import argparse

    p = argparse.ArgumentParser(description="Capture a scrubbed CI fixture from Elastic.")
    p.add_argument("detonation_id", help="fixture dir name under tests/fixtures/")
    p.add_argument("--index", required=True)
    p.add_argument("--host", required=True)
    p.add_argument("--start", required=True, help="ISO8601 UTC")
    p.add_argument("--end", required=True, help="ISO8601 UTC")
    p.add_argument("--fixtures-root", type=Path, default=Path("tests/fixtures"))
    args = p.parse_args()

    auth = _prompt_auth()
    hits = fetch_window(args.index, args.host, args.start, args.end, auth)
    if not hits:
        sys.exit("no events in window — check index, host, and time range")
    write_fixture(args.fixtures_root / args.detonation_id, hits, fetch_mappings(args.index, auth))
