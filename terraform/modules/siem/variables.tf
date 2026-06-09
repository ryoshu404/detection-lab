variable "environment" {
  description = "Deployment environment (lab/dev/prod). Used in resource names and tags."
  type        = string
}

variable "vpc_id" {
  description = "VPC for the security group. From the networking module."
  type        = string
}

variable "vpc_cidr_block" {
  description = "VPC CIDR, for the security group inbound rules. From the networking module."
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet to place the instance in. From the networking module."
  type        = string
}

variable "instance_profile_name" {
  description = "EC2 instance profile (SSM + S3 read). From the iam module."
  type        = string
}

variable "instance_type" {
  description = "Elastic + Kibana single-node sizing."
  type        = string
  default     = "t3.medium"
}

variable "ebs_volume_size_gb" {
  description = "Size of the encrypted gp3 volume for Elasticsearch indices."
  type        = number
  default     = 50
}
