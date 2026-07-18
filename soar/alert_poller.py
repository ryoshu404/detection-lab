#!/usr/bin/env python3
"""Poll the Elastic detection alerts index and push new alerts to a Tines webhook.

One-directional: Elastic -> Tines. Tracks a last-seen timestamp plus recently-sent
alert UUIDs so alerts that arrive slightly out of order are still caught without
being re-sent (dedup is on the alert UUID, not the timestamp alone).
"""

import json
import os
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone, timedelta
from pathlib import Path

# --- Config from environment ---
ES_URL = os.environ["ES_URL"].rstrip("/")
ES_API_KEY = os.environ["ES_API_KEY"]
TINES_WEBHOOK_URL = os.environ["TINES_WEBHOOK_URL"]
ALERTS_INDEX = os.environ.get("ALERTS_INDEX", ".alerts-security.alerts-default")
STATE_FILE = Path(os.environ.get("STATE_FILE", "/var/lib/alert-poller/state.json"))
# How far back to re-query each run, to catch out-of-order/late-arriving alerts.
OVERLAP_MINUTES = int(os.environ.get("OVERLAP_MINUTES", "5"))
# Verify TLS against the ES CA. For a lab with a self-signed cert, point this at
# the CA file; if unset, TLS verification is skipped.
ES_CA_CERT = os.environ.get("ES_CA_CERT", "")

import ssl
if ES_CA_CERT:
    SSL_CTX = ssl.create_default_context(cafile=ES_CA_CERT)
else:
    SSL_CTX = ssl.create_default_context()
    SSL_CTX.check_hostname = False
    SSL_CTX.verify_mode = ssl.CERT_NONE


def log(msg):
    print(f"{datetime.now(timezone.utc).isoformat()} {msg}", flush=True)


def load_state():
    try:
        with STATE_FILE.open() as f:
            state = json.load(f)
            state["sent_uuids"] = set(state.get("sent_uuids", []))
            return state
    except (FileNotFoundError, json.JSONDecodeError):
        # First run: start from now minus the overlap window.
        start = datetime.now(timezone.utc) - timedelta(minutes=OVERLAP_MINUTES)
        return {"last_seen": start.isoformat(), "sent_uuids": set()}


def save_state(state):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    out = {"last_seen": state["last_seen"], "sent_uuids": sorted(state["sent_uuids"])}
    tmp = STATE_FILE.with_suffix(".tmp")
    with tmp.open("w") as f:
        json.dump(out, f)
    tmp.replace(STATE_FILE)


def query_alerts(since_iso):
    """Fetch alerts with @timestamp >= (since - overlap), newest handling by caller."""
    window_start = (
        datetime.fromisoformat(since_iso) - timedelta(minutes=OVERLAP_MINUTES)
    ).isoformat()
    body = {
        "size": 500,
        "sort": [{"@timestamp": "asc"}],
        "query": {
            "bool": {
                "filter": [
                    {"range": {"@timestamp": {"gte": window_start}}}
                ]
            }
        },
    }
    req = urllib.request.Request(
        f"{ES_URL}/{ALERTS_INDEX}/_search",
        data=json.dumps(body).encode(),
        headers={
            "Authorization": f"ApiKey {ES_API_KEY}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, context=SSL_CTX, timeout=30) as resp:
        data = json.loads(resp.read())
    return data.get("hits", {}).get("hits", [])


def post_to_tines(alert_source):
    req = urllib.request.Request(
        TINES_WEBHOOK_URL,
        data=json.dumps(alert_source).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, context=SSL_CTX, timeout=30) as resp:
        return resp.status


def alert_uuid(hit):
    return hit["_source"].get("kibana.alert.uuid") or hit.get("_id")


def prune_uuids(state):
    """Keep sent_uuids from growing unbounded: drop UUIDs older than the overlap
    window is hard without per-uuid timestamps, so cap the set size instead."""
    if len(state["sent_uuids"]) > 5000:
        state["sent_uuids"] = set(list(state["sent_uuids"])[-5000:])


def run_once():
    state = load_state()
    try:
        hits = query_alerts(state["last_seen"])
    except urllib.error.URLError as e:
        log(f"ERROR querying Elasticsearch: {e}")
        return
    except Exception as e:
        log(f"ERROR querying Elasticsearch: {e}")
        return

    new_sent = 0
    latest_ts = state["last_seen"]
    for hit in hits:
        uid = alert_uuid(hit)
        if uid in state["sent_uuids"]:
            continue
        try:
            status = post_to_tines(hit["_source"])
        except Exception as e:
            log(f"ERROR posting alert {uid} to Tines: {e}")
            continue
        if 200 <= status < 300:
            state["sent_uuids"].add(uid)
            new_sent += 1
            ts = hit["_source"].get("@timestamp", latest_ts)
            if ts > latest_ts:
                latest_ts = ts
        else:
            log(f"WARN Tines returned {status} for alert {uid}")

    state["last_seen"] = latest_ts
    prune_uuids(state)
    save_state(state)
    if new_sent:
        log(f"pushed {new_sent} new alert(s) to Tines")


def main():
    # Single-shot mode (systemd timer calls this each interval).
    run_once()


if __name__ == "__main__":
    main()
