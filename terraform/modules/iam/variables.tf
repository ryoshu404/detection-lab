variable "environment" {
  description = "Deployment environment (lab/dev/prod). Used in resource names."
  type        = string
}

variable "log_bucket_arns" {
  description = "Telemetry bucket ARNs the Elastic instance (Filebeat) reads from."
  type        = list(string)
}
