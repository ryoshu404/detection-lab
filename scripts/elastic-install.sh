#!/usr/bin/env bash
# Elastic 9.x single-node install for the detection-lab SIEM instance.
# Run as root over SSM on a fresh Ubuntu 22.04 host with the data volume attached.
set -euo pipefail

DATA_MOUNT="/var/lib/elasticsearch"
ES_HEAP="4g"

# Data volume = the disk that doesn't host root. Format only if blank.
ROOT_DISK="/dev/$(lsblk -no PKNAME "$(findmnt -no SOURCE /)")"
DATA_DEV="$(lsblk -dpno NAME,TYPE | awk '$2=="disk"{print $1}' \
  | grep -v "^${ROOT_DISK}$" | head -n1)"

if ! mountpoint -q "$DATA_MOUNT"; then
  mkdir -p "$DATA_MOUNT"
  blkid "$DATA_DEV" >/dev/null 2>&1 || mkfs.ext4 "$DATA_DEV"
  mount "$DATA_DEV" "$DATA_MOUNT"
  UUID="$(blkid -s UUID -o value "$DATA_DEV")"
  grep -q "$UUID" /etc/fstab \
    || echo "UUID=$UUID $DATA_MOUNT ext4 defaults,nofail 0 2" >> /etc/fstab
fi

# A non-empty data dir makes the package skip security autoconfig (no
# password, no certs). mkfs leaves lost+found, so clear it before install.
rm -rf "$DATA_MOUNT/lost+found"

if [ ! -f /usr/share/keyrings/elasticsearch-keyring.gpg ]; then
  wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch \
    | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
fi
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/9.x/apt stable main" \
  > /etc/apt/sources.list.d/elastic-9.x.list
apt-get update
apt-get install -y elasticsearch

# Data dir was prepped as root; chown after install so ES can write node.lock.
chown -R elasticsearch:elasticsearch "$DATA_MOUNT"

printf -- "-Xms%s\n-Xmx%s\n" "$ES_HEAP" "$ES_HEAP" \
  > /etc/elasticsearch/jvm.options.d/heap.options

systemctl daemon-reload
systemctl enable --now elasticsearch.service
