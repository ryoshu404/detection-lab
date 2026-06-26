#!/usr/bin/env bash
# Filebeat 9.x: ship CloudTrail from the SQS-notified S3 bucket to local Elasticsearch.
# Local Proxmox VM variant: no instance role, so AWS creds live in the keystore.
# Usage: filebeat-install-local.sh <sqs-queue-url>
set -euo pipefail

QUEUE_URL="${1:?Usage: filebeat-install-local.sh <sqs-queue-url>}"

apt-get install -y filebeat
filebeat modules enable aws

# Only the cloudtrail fileset; AWS creds referenced from the keystore.
cat > /etc/filebeat/modules.d/aws.yml << EOF
- module: aws
  cloudtrail:
    enabled: true
    var.queue_url: ${QUEUE_URL}
    var.access_key_id: \${AWS_ACCESS_KEY_ID}
    var.secret_access_key: \${AWS_SECRET_ACCESS_KEY}
  cloudwatch:
    enabled: false
  ec2:
    enabled: false
  elb:
    enabled: false
  s3access:
    enabled: false
  vpcflow:
    enabled: false
EOF

# Secrets into the keystore, never plaintext. All three prompted, not echoed.
filebeat keystore create --force
read -rsp "Elastic password: " ES_PW; echo
printf '%s' "$ES_PW" | filebeat keystore add ES_PWD --stdin --force
unset ES_PW
read -rsp "AWS access key ID: " AWS_AKID; echo
printf '%s' "$AWS_AKID" | filebeat keystore add AWS_ACCESS_KEY_ID --stdin --force
unset AWS_AKID
read -rsp "AWS secret access key: " AWS_SECRET; echo
printf '%s' "$AWS_SECRET" | filebeat keystore add AWS_SECRET_ACCESS_KEY --stdin --force
unset AWS_SECRET

# Quoted heredoc so ${...} stays literal for Filebeat to resolve at runtime.
cat > /etc/filebeat/filebeat.yml << 'EOF'
filebeat.config.modules:
  path: ${path.config}/modules.d/*.yml
  reload.enabled: false

setup.kibana:
  host: "http://localhost:5601"

output.elasticsearch:
  hosts: ["https://localhost:9200"]
  username: "elastic"
  password: "${ES_PWD}"
  ssl.certificate_authorities: ["/etc/elasticsearch/certs/http_ca.crt"]
EOF

until curl -s -o /dev/null http://localhost:5601; do sleep 5; done

filebeat setup -e
systemctl enable --now filebeat
