output "elastic_instance_role_arn" {
  description = "ARN of the Elastic EC2 instance role."
  value       = aws_iam_role.elastic_instance.arn
}

output "elastic_instance_profile_name" {
  description = "Instance profile name, attached to the Elastic EC2 instance at T9."
  value       = aws_iam_instance_profile.elastic_instance.name
}

output "filebeat_local_access_key_id" {
  description = "Access key ID for the local Filebeat user."
  value       = aws_iam_access_key.filebeat_local.id
}

output "filebeat_local_secret_access_key" {
  description = "Secret access key for the local Filebeat user."
  value       = aws_iam_access_key.filebeat_local.secret
  sensitive   = true
}
