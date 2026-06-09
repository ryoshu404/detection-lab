variable "environment" {
  description = "Deployment environment (lab/dev/prod). Used in bucket names and tags."
  type        = string
}

variable "aws_region" {
  description = "AWS region, used in the Flow Logs delivery SourceArn condition."
  type        = string
  default     = "us-east-1"
}

variable "log_retention_days" {
  description = "Days before objects expire (lifecycle expiration)."
  type        = number
  default     = 365
}

variable "transition_to_glacier_days" {
  description = "Days before objects transition to Glacier Instant Retrieval."
  type        = number
  default     = 90
}

variable "kms_key_arn" {
  description = "Optional KMS CMK ARN for bucket encryption. Null uses SSE-S3 (AES256)."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Allow Terraform to delete non-empty buckets. Keep false for sustained operation; set true only for dev teardown."
  type        = bool
  default     = false
}
