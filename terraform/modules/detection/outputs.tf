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
