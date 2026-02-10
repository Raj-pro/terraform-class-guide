# Development Environment
output "dev_server_id" {
  description = "Dev server instance ID"
  value       = module.dev_server.instance_id
}

output "dev_server_public_ip" {
  description = "Dev server public IP"
  value       = module.dev_server.public_ip
}

output "dev_server_url" {
  description = "Dev server URL"
  value       = "http://${module.dev_server.public_ip}"
}

# Production Environment
output "prod_server_id" {
  description = "Prod server instance ID"
  value       = module.prod_server.instance_id
}

output "prod_server_public_ip" {
  description = "Prod server public IP"
  value       = module.prod_server.public_ip
}

output "prod_server_url" {
  description = "Prod server URL"
  value       = "http://${module.prod_server.public_ip}"
}

# VPC
output "vpc_id" {
  description = "Shared VPC ID"
  value       = aws_vpc.shared.id
}
