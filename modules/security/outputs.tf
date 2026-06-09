output "ec2_sg_id" {
  description = "Security group ID — passed to the compute module"
  value       = aws_security_group.main.id
}