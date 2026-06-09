output "cloudtrail_arn" {
  description = "ARN of the CloudTrail trail."
  value       = aws_cloudtrail.this.arn
}

output "flow_logs_id" {
  description = "VPC Flow Log ID."
  value       = aws_flow_log.this.id
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID, for tuning and the findings export wired at T9."
  value       = aws_guardduty_detector.this.id
}

output "cloudtrail_sqs_queue_arn" {
  description = "CloudTrail notification queue ARN; consumed by iam/ for Filebeat read perms"
  value       = aws_sqs_queue.cloudtrail_notifications.arn
}

output "cloudtrail_sqs_queue_url" {
  description = "CloudTrail notification queue URL for Filebeat aws-s3 input"
  value       = aws_sqs_queue.cloudtrail_notifications.id
}
