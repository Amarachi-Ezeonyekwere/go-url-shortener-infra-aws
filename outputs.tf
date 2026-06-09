output "ec2_public_ip" {
  description = "Public IP — your app runs at http://<this-ip>"
  value       = module.compute.ec2_public_ip
}

output "app_url" {
  description = "Direct link to the running application"
  value       = "http://${module.compute.ec2_public_ip}"
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = "ssh -i ~/.ssh/linux_key.pem ubuntu@${module.compute.ec2_public_ip}"
}