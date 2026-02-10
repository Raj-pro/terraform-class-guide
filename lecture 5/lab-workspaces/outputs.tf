output "workspace_name" {
  description = "Current workspace name"
  value       = terraform.workspace
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "instance_type" {
  description = "Instance type used for this workspace"
  value       = local.config.instance_type
}

output "instance_count" {
  description = "Number of instances in this workspace"
  value       = local.config.instance_count
}

output "instance_ips" {
  description = "Public IPs of all instances"
  value       = aws_instance.web[*].public_ip
}
