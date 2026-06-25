output "cloudtrail_bucket_arn" {
  description = "CloudTrail log bucket ARN. Consumed by detection/ for the trail destination."
  value       = aws_s3_bucket.this["cloudtrail"].arn
}

output "cloudtrail_bucket_name" {
  description = "CloudTrail log bucket name, for SIEM/Filebeat configuration."
  value       = aws_s3_bucket.this["cloudtrail"].id
}

output "guardduty_bucket_arn" {
  description = "GuardDuty findings bucket ARN. Consumed by detection/."
  value       = aws_s3_bucket.this["guardduty"].arn
}

output "flowlogs_bucket_arn" {
  description = "VPC Flow Logs bucket ARN. Consumed by detection/."
  value       = aws_s3_bucket.this["flowlogs"].arn
}

output "archive_bucket_arn" {
  description = "General-purpose log archive bucket ARN."
  value       = aws_s3_bucket.this["archive"].arn
}

output "guardduty_kms_key_arn" {
  description = "KMS key ARN for GuardDuty findings export"
  value       = aws_kms_key.guardduty.arn
}
