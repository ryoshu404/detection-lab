variable "environment" {
  description = "Deployment environment (lab/dev/prod). Used in resource names and tags."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. /16 gives room for /24 subnets via cidrsubnet()."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to span. One public and one private subnet are created per AZ."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "enable_nat" {
  description = "Create a single NAT gateway so private subnets have outbound internet. Set false to avoid the NAT's hourly charge when egress isn't needed (e.g. early dev before the SIEM exists)."
  type        = bool
  default     = true
}
