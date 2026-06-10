output "siem_instance_id" {
  description = "EC2 instance ID, for SSM session targeting."
  value       = aws_instance.this.id
}

output "siem_security_group_id" {
  description = "Security group ID, for future modules that need to reach Elastic (e.g. SOAR)."
  value       = aws_security_group.siem.id
}

output "siem_private_ip" {
  description = "Private IP for Kibana access via SSM port forwarding."
  value       = aws_instance.this.private_ip
}
