variable "environment" {
  description = "Deployment environment (lab/dev/prod). Used in resource names and tags."
  type        = string
  default     = "lab"
}

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "force_destroy" {
  description = "Allow Terraform to delete non-empty buckets (dev teardown only)."
  type        = bool
  default     = false
}
