output "ec2_instance_profile_name" {
  description = "Instance profile name — passed to the compute module"
  value       = aws_iam_instance_profile.ec2_profile.name
}