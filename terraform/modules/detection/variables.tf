variable "environment" {
  description = "Deployment environment (lab/dev/prod). Used in resource names and tags."
  type        = string
}

variable "vpc_id" {
  description = "VPC to attach Flow Logs to. From the networking module."
  type        = string
}

variable "cloudtrail_bucket_name" {
  description = "Name of the CloudTrail log bucket. From the storage module."
  type        = string
}

variable "cloudtrail_bucket_arn" {
  description = "ARN of the CloudTrail log bucket, used to exclude it from S3 data events."
  type        = string
}

variable "flowlogs_bucket_arn" {
  description = "ARN of the Flow Logs bucket. From the storage module."
  type        = string
}

variable "multi_region_trail" {
  description = "Whether the trail spans all regions."
  type        = bool
  default     = true
}

variable "enable_s3_data_events" {
  description = "Log S3 object-level data events (excluding the trail's own log bucket)."
  type        = bool
  default     = true
}

variable "guardduty_bucket_arn" {
  description = "GuardDuty findings bucket ARN (S3 export destination)"
  type        = string
}

variable "guardduty_kms_key_arn" {
  description = "KMS key ARN for GuardDuty findings export encryption"
  type        = string
}
