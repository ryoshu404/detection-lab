output "siem_instance_id" {
  description = "SIEM EC2 instance ID for SSM session targeting"
  value       = module.siem.siem_instance_id
}

output "cloudtrail_sqs_queue_url" {
  description = "CloudTrail notification queue URL"
  value       = module.detection.cloudtrail_sqs_queue_url
}
