"""Inject burn-in state and ownership into compiled Detection Engine rules.

The Detection Engine has no "run but don't page" mode, so the lab models it as
a tag the SOAR layer branches on: enabled is always true (the rule runs and
generates detections), and an alerting:false (burn-in) or alerting:true
(promoted) tag decides whether a firing becomes a case.

Every rule the pipeline deploys also gets a managed-by:detection-lab tag. That
ownership marker is what lets retire.py safely reconcile as rules the pipeline
never deployed don't carry it and are never candidates for deletion. The tag is
injected here rather than declared in the Sigma rule because it's a fact about
how the rule was deployed, not a property of the rule, and because pySigma
normalizes Sigma tags in ways that would mangle a key:value string.

The Sigma rule declares `alerting` as a custom field, read from the raw YAML
because pySigma drops fields it doesn't model. Absent = false (burn-in default).
"""

from __future__ import annotations

import yaml
from pathlib import Path

ALERTING_TAG_PREFIX = "alerting:"
MANAGED_TAG = "managed-by:detection-lab"


def read_alerting_state(rule_path: Path) -> dict[str, bool]:
    states: dict[str, bool] = {}
    for doc in yaml.safe_load_all(rule_path.read_text()):
        if not isinstance(doc, dict):
            continue
        rule_id = doc.get("id")
        if rule_id is None:
            continue
        states[str(rule_id)] = bool(doc.get("alerting", False))
    return states


def inject_alerting_tag(ndjson_rule: dict, alerting: bool) -> dict:
    tags = [t for t in ndjson_rule.get("tags", [])
            if not t.startswith(ALERTING_TAG_PREFIX) and t != MANAGED_TAG]
    tags.append(f"{ALERTING_TAG_PREFIX}{'true' if alerting else 'false'}")
    tags.append(MANAGED_TAG)
    ndjson_rule["tags"] = tags
    ndjson_rule["enabled"] = True
    return ndjson_rule


def apply_alerting_tags(ndjson_rules: list[dict], rules_path: Path) -> list[dict]:
    states: dict[str, bool] = {}
    if rules_path.is_dir():
        for f in rules_path.rglob("*.yml"):
            states.update(read_alerting_state(f))
    else:
        states.update(read_alerting_state(rules_path))

    out = []
    for rule in ndjson_rules:
        rid = str(rule.get("rule_id") or rule.get("id") or "")
        out.append(inject_alerting_tag(rule, states.get(rid, False)))
    return out


if __name__ == "__main__":
    import argparse
    import json
    from compile import compile_rules

    parser = argparse.ArgumentParser(description="Compile rules and inject burn-in tags.")
    parser.add_argument("rules", type=Path)
    parser.add_argument("-p", "--pipeline", type=Path, required=True)
    args = parser.parse_args()

    compiled = compile_rules(args.rules, args.pipeline, output_format="siem_rule_ndjson")
    compiled = [json.loads(c) if isinstance(c, str) else c for c in compiled]

    for rule in apply_alerting_tags(compiled, args.rules):
        print(json.dumps(rule))
