# SOAR alert poller

Pushes new Elastic detection alerts to a Tines webhook (Elastic -> Tines, one-directional).

## Why a poller
Elastic's native webhook connector is a paid (Gold+) feature. On Basic, this small
forwarder bridges the gap: it reads the security alerts index with a scoped API key
and POSTs each new alert to a Tines webhook. Dedup is by alert UUID within an overlap
window, so out-of-order alerts are caught without re-sending. See ADR-003.

## Install (on the Elastic VM)
```bash
# 1. Create a dedicated user + dirs
sudo useradd --system --no-create-home --shell /usr/sbin/nologin alert-poller
sudo mkdir -p /opt/alert-poller /var/lib/alert-poller /etc/alert-poller
sudo cp alert_poller.py /opt/alert-poller/
sudo chown -R alert-poller:alert-poller /var/lib/alert-poller

# 2. Config (secrets live here, not in the repo)
sudo cp config.env.example /etc/alert-poller/config.env
sudo chmod 600 /etc/alert-poller/config.env
sudo chown alert-poller:alert-poller /etc/alert-poller/config.env
# then edit /etc/alert-poller/config.env and fill in ES_API_KEY + TINES_WEBHOOK_URL

# 3. Systemd
sudo cp alert-poller.service alert-poller.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now alert-poller.timer

# 4. Test one run manually
sudo systemctl start alert-poller.service
journalctl -u alert-poller.service --no-pager -n 20
```

## Files
- `alert_poller.py` — the poller (single-shot; the timer runs it each interval)
- `config.env.example` — config template (real one lives at /etc/alert-poller/config.env on the VM)
- `alert-poller.service` / `alert-poller.timer` — systemd unit + 60s timer
