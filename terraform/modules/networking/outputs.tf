output "vpc_id" {
  description = "VPC ID. Consumed by detection/ (Flow Logs) and siem/ (Elastic instance placement)."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR. Used by siem/ for security-group inbound rules scoped to the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs. The Elastic instance goes here."
  value       = aws_subnet.private[*].id
}

output "default_security_group_id" {
  description = "The VPC's default security group ID, exposed for tightening later."
  value       = aws_vpc.this.default_security_group_id
}
