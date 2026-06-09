#!/usr/bin/env bash
# Filebeat 9.x: ship CloudTrail from the SQS-notified S3 bucket to local Elasticsearch.
# Run as root over SSM after Elasticsearch and Kibana are up.
# Usage: filebeat-install.sh <sqs-queue-url>   (prompts for the elastic password)
set -euo pipefail

QUEUE_URL="${1:?Usage: filebeat-install.sh <sqs-queue-url>}"

apt-get install -y filebeat
filebeat modules enable aws

# Only the cloudtrail fileset on; the rest off so they don't warn about no queue_url.
# Unquoted heredoc so ${QUEUE_URL} expands from this script.
cat > /etc/filebeat/modules.d/aws.yml << EOF
- module: aws
  cloudtrail:
    enabled: true
    var.queue_url: ${QUEUE_URL}
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

# elastic password into the keystore, never plaintext in config. Prompted, not echoed.
read -rsp "Elastic password: " ES_PW_TMP; echo
filebeat keystore create --force
printf '%s' "$ES_PW_TMP" | filebeat keystore add ES_PWD --stdin --force
unset ES_PW_TMP

# Quoted heredoc so ${path.config} and ${ES_PWD} stay literal for Filebeat to resolve.
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

# Kibana must be serving before setup loads its dashboards.
until curl -s -o /dev/null http://localhost:5601; do sleep 5; done

filebeat setup -e
systemctl enable --now filebeat
