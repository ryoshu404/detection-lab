def query_alerts(since_iso):
    """Fetch alerts with @timestamp >= (since - overlap), newest handling by caller."""
    window_start = (
        _parse_iso(since_iso) - timedelta(minutes=OVERLAP_MINUTES)
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
    # Prefer the alert's own UUID; fall back to the ES _id.
    return hit["_source"].get("kibana.alert.uuid") or hit.get("_id")


def prune_uuids(state):
    """Keep sent_uuids from growing unbounded: drop UUIDs older than the overlap
    window is hard without per-uuid timestamps, so cap the set size instead."""
    if len(state["sent_uuids"]) > 5000:
        # Keep it bounded; oldest-tracking isn't needed because dedup only matters
        # within the overlap window. A large cap is plenty for lab volume.
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
            continue  # already pushed
        try:
            status = post_to_tines(hit["_source"])
        except Exception as e:
            log(f"ERROR posting alert {uid} to Tines: {e}")
            # Don't mark as sent; retry next run.
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
