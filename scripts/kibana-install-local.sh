#!/usr/bin/env bash
# Kibana 9.x install + enroll against the local Elasticsearch node.
# Run as root over SSM after elastic-install.sh has Elasticsearch up.
set -euo pipefail

apt-get install -y kibana

# Wait for Elasticsearch to respond before requesting an enrollment token.
until curl -ks https://localhost:9200 >/dev/null; do sleep 5; done

# Generate a kibana enrollment token on the ES side and consume it right away
# (tokens expire in 30 min; ES and Kibana are co-located so we do both here).
TOKEN="$(/usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana)"
/usr/share/kibana/bin/kibana-setup --enrollment-token "$TOKEN"

# Without these, Fleet's setup loops forever on a missing-encryption-key error.
grep -q "xpack.encryptedSavedObjects.encryptionKey" /etc/kibana/kibana.yml || {
  echo "" >> /etc/kibana/kibana.yml
  /usr/share/kibana/bin/kibana-encryption-keys generate -q >> /etc/kibana/kibana.yml
}

systemctl daemon-reload
systemctl enable --now kibana
