output "security_group_id" {
  description = "The ID of the security group. Crucial for attaching to compute resources or referencing in other security group rules."
  value       = aws_security_group.main.id
}

output "security_group_arn" {
  description = "The Amazon Resource Name of the security group. Useful for IAM policies, logging configurations, or cross-account access controls."
  value       = aws_security_group.main.arn
}