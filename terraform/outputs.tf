output "cloudtrail_sqs_queue_url" {
  description = "CloudTrail notification queue URL"
  value       = module.detection.cloudtrail_sqs_queue_url
}

output "filebeat_local_access_key_id" {
  value = module.iam.filebeat_local_access_key_id
}

output "filebeat_local_secret_access_key" {
  value     = module.iam.filebeat_local_secret_access_key
  sensitive = true
}

output "elastic_snapshot_bucket_name" {
  value = module.storage.elastic_snapshot_bucket_name
}

output "elastic_snapshot_access_key_id" {
  value = module.iam.elastic_snapshot_access_key_id
}

output "elastic_snapshot_secret_access_key" {
  value     = module.iam.elastic_snapshot_secret_access_key
  sensitive = true
}
