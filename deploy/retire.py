"""Retire rules that have left the repo.

Fetches every Detection Engine rule tagged managed-by:detection-lab and deletes
any whose rule_id is no longer backed by a source file in detections/. The
ownership tag keeps this safe: rules the pipeline never deployed don't carry it
and are never considered for deletion.

Credentials from the environment: KIBANA_URL, KIBANA_API_KEY.
"""

from __future__ import annotations

import os
from pathlib import Path

import requests
import yaml

MANAGED_TAG = "managed-by:detection-lab"


class RetireError(RuntimeError):
    pass


def _config() -> tuple[str, str]:
    url = os.environ.get("KIBANA_URL")
    api_key = os.environ.get("KIBANA_API_KEY")
    missing = [k for k, v in {"KIBANA_URL": url, "KIBANA_API_KEY": api_key}.items() if not v]
    if missing:
        raise RetireError(f"Missing environment variables: {', '.join(missing)}")
    return url.rstrip("/"), api_key


def _headers(api_key: str) -> dict:
    return {"kbn-xsrf": "true", "Authorization": f"ApiKey {api_key}"}


def repo_rule_ids(detections_dir: Path) -> set[str]:
    ids: set[str] = set()
    for f in detections_dir.rglob("*.yml"):
        for doc in yaml.safe_load_all(f.read_text()):
            if isinstance(doc, dict) and doc.get("id"):
                ids.add(str(doc["id"]))
    return ids


def managed_rules_in_siem(url: str, api_key: str) -> list[dict]:
    rules: list[dict] = []
    page = 1
    while True:
        resp = requests.get(
            f"{url}/api/detection_engine/rules/_find",
            params={"per_page": 100, "page": page,
                    "filter": f'alert.attributes.tags:"{MANAGED_TAG}"'},
            headers=_headers(api_key), timeout=30)
        if resp.status_code != 200:
            raise RetireError(f"_find failed [{resp.status_code}]: {resp.text}")
        data = resp.json()
        rules.extend(data.get("data", []))
        if page * 100 >= data.get("total", 0):
            break
        page += 1
    return rules


def delete_rule(url: str, api_key: str, rule_id: str) -> None:
    resp = requests.delete(
        f"{url}/api/detection_engine/rules",
        params={"rule_id": rule_id}, headers=_headers(api_key), timeout=30)
    if resp.status_code != 200:
        raise RetireError(f"delete of {rule_id} failed [{resp.status_code}]: {resp.text}")


def reconcile(detections_dir: Path, dry_run: bool = False) -> list[str]:
    url, api_key = _config()
    repo_ids = repo_rule_ids(detections_dir)
    managed = managed_rules_in_siem(url, api_key)
    orphans = [r for r in managed if str(r.get("rule_id")) not in repo_ids]

    retired = []
    for rule in orphans:
        rid = str(rule.get("rule_id"))
        name = rule.get("name", rid)
        if dry_run:
            print(f"[dry-run] would retire: {name} ({rid})")
        else:
            delete_rule(url, api_key, rid)
            print(f"retired: {name} ({rid})")
        retired.append(rid)
    if not retired:
        print("nothing to retire — SIEM matches repo")
    return retired


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Retire managed rules absent from the repo.")
    parser.add_argument("detections", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    reconcile(args.detections, dry_run=args.dry_run)
