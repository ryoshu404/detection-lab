"""Import compiled rules into the Detection Engine.

overwrite=true updates a rule matched by rule_id rather than erroring, which is
what makes promotion (flipping the alerting tag and redeploying) work without
creating a duplicate.

Credentials come from the environment:
    KIBANA_URL
    KIBANA_API_KEY
"""

from __future__ import annotations

import io
import json
import os
from pathlib import Path

import requests


class PushError(RuntimeError):
    pass


def _config() -> tuple[str, str]:
    url = os.environ.get("KIBANA_URL")
    api_key = os.environ.get("KIBANA_API_KEY")
    missing = [k for k, v in {"KIBANA_URL": url, "KIBANA_API_KEY": api_key}.items() if not v]
    if missing:
        raise PushError(f"Missing environment variables: {', '.join(missing)}")
    return url.rstrip("/"), api_key


def rules_to_ndjson(rules: list[dict]) -> bytes:
    return ("\n".join(json.dumps(r) for r in rules) + "\n").encode("utf-8")


def push_rules(rules: list[dict], overwrite: bool = True) -> dict:
    url, api_key = _config()
    resp = requests.post(
        f"{url}/api/detection_engine/rules/_import",
        params={"overwrite": str(overwrite).lower()},
        headers={"kbn-xsrf": "true", "Authorization": f"ApiKey {api_key}"},
        files={"file": ("rules.ndjson", io.BytesIO(rules_to_ndjson(rules)), "application/ndjson")},
        timeout=30,
    )
    if resp.status_code != 200:
        raise PushError(f"Import failed [{resp.status_code}]: {resp.text}")

    result = resp.json()
    # _import returns 200 even when a rule fails; the failures are in the body.
    if result.get("errors"):
        raise PushError(f"Import reported rule errors: {json.dumps(result['errors'], indent=2)}")
    return result


if __name__ == "__main__":
    import argparse
    from compile import compile_rules
    from burnin import apply_alerting_tags

    parser = argparse.ArgumentParser(description="Compile, tag, and push rules to Elastic.")
    parser.add_argument("rules", type=Path)
    parser.add_argument("-p", "--pipeline", type=Path, required=True)
    parser.add_argument("--no-overwrite", action="store_true")
    args = parser.parse_args()

    compiled = compile_rules(args.rules, args.pipeline, output_format="siem_rule_ndjson")
    compiled = [json.loads(c) if isinstance(c, str) else c for c in compiled]
    tagged = apply_alerting_tags(compiled, args.rules)

    print(json.dumps(push_rules(tagged, overwrite=not args.no_overwrite), indent=2))
