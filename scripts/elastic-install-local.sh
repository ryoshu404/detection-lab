#!/usr/bin/env bash
# Elastic 9.x single-node install for the local detection-lab SIEM VM (Proxmox).
# Single-disk host (no separate data volume). Run as root on fresh Ubuntu 22.04.
set -euo pipefail

ES_HEAP="4g"

# Repo
if [ ! -f /usr/share/keyrings/elasticsearch-keyring.gpg ]; then
  wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch \
    | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
fi
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/9.x/apt stable main" \
  > /etc/apt/sources.list.d/elastic-9.x.list
apt-get update
apt-get install -y elasticsearch

# Heap sizing for an 8GB VM (~half of RAM, capped well under the 32GB compressed-oops line).
printf -- "-Xms%s\n-Xmx%s\n" "$ES_HEAP" "$ES_HEAP" \
  > /etc/elasticsearch/jvm.options.d/heap.options

systemctl daemon-reload
systemctl enable --now elasticsearch.service
