variable "environment" {
  description = "Deployment environment (lab/dev/prod). Used in resource names."
  type        = string
}

variable "log_bucket_arns" {
  description = "Telemetry bucket ARNs the Elastic instance (Filebeat) reads from."
  type        = list(string)
}

variable "cloudtrail_sqs_queue_arn" {
  description = "CloudTrail notification queue ARN; grants Filebeat SQS receive/delete"
  type        = string
}

variable "guardduty_detector_arn" {
  description = "GuardDuty detector ARN; grants the Agent findings read access."
  type        = string
}
