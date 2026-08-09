"""Each fixture's rule must match exactly its labelled events. One parametrized
case per tests/fixtures/<id>/labels.yml. ES connection defaults to the CI
container; override with HARNESS_ES / HARNESS_ES_USER / HARNESS_ES_PASSWORD."""

from __future__ import annotations

import json
import os
import re
import sys
import time
from pathlib import Path

import pytest
import requests
import urllib3
import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "deploy"))
from compile import compile_rules  # noqa: E402

ES = os.environ.get("HARNESS_ES", "http://localhost:9200").rstrip("/")
_USER = os.environ.get("HARNESS_ES_USER")
AUTH = (_USER, os.environ.get("HARNESS_ES_PASSWORD")) if _USER else None
VERIFY = ES.startswith("http://")
if not VERIFY:
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

PIPELINE = Path("pipelines/lab-ecs.yml")
FIXTURES = sorted(Path("tests/fixtures").glob("*/labels.yml"))
FROM_INDEX = re.compile(r"(?i)\bfrom\s+(\S+)")


def _req(method: str, path: str, **kw):
    return requests.request(method, f"{ES}{path}", auth=AUTH, verify=VERIFY, timeout=60, **kw)


@pytest.fixture(scope="session", autouse=True)
def _wait_for_es():
    for _ in range(120):
        try:
            if _req("GET", "/").status_code == 200:
                return
        except requests.exceptions.RequestException:
            pass
        time.sleep(1)
    pytest.fail("elasticsearch did not become ready")


def _load(fixture_dir: Path, index: str) -> None:
    mappings = json.loads((fixture_dir / "mappings.json").read_text())
    body = next(iter(mappings.values())).get("mappings", {}) if mappings else {}
    _req("DELETE", f"/{index}")
    _req("PUT", f"/{index}", json={"mappings": body})

    lines = []
    for raw in (fixture_dir / "events.ndjson").read_text().splitlines():
        if not raw.strip():
            continue
        rec = json.loads(raw)
        lines.append(json.dumps({"index": {"_index": index, "_id": rec["_id"]}}))
        lines.append(json.dumps(rec["_source"]))
    resp = _req("POST", "/_bulk?refresh=true",
                data="\n".join(lines) + "\n",
                headers={"Content-Type": "application/x-ndjson"})
    assert not resp.json().get("errors"), f"bulk load errors: {resp.text[:500]}"


def _query_ids(esql: str, index: str) -> set[str]:
    esql = FROM_INDEX.sub(f"FROM {index}", esql, count=1)
    resp = _req("POST", "/_query", json={"query": esql})
    assert resp.status_code == 200, f"query failed: {resp.text[:500]}"
    data = resp.json()
    cols = [c["name"] for c in data["columns"]]
    return {row[cols.index("_id")] for row in data["values"]}


@pytest.mark.parametrize("labels_path", FIXTURES, ids=lambda p: p.parent.name)
def test_rule_matches_fixture(labels_path: Path):
    labels = yaml.safe_load(labels_path.read_text())
    fixture_dir = labels_path.parent
    rule_path = Path("detections") / labels["rule"] / "rule.yml"
    index = "test-" + fixture_dir.name.lower().replace(".", "-").replace("_", "-")

    expected: set[str] = set()
    for ds in labels["datasets"]:
        expected.update(ds["attack_event_ids"])

    try:
        _load(fixture_dir, index)
        esql = compile_rules(rule_path, PIPELINE, "default")[0]
        actual = _query_ids(esql, index)
    finally:
        _req("DELETE", f"/{index}")

    assert actual == expected
