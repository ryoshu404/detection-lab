output "elastic_instance_role_arn" {
  description = "ARN of the Elastic EC2 instance role."
  value       = aws_iam_role.elastic_instance.arn
}

output "elastic_instance_profile_name" {
  description = "Instance profile name, attached to the Elastic EC2 instance at T9."
  value       = aws_iam_instance_profile.elastic_instance.name
}
