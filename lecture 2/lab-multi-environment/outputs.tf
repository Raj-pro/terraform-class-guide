output "environment" {
  description = "Deployment environment"
  value       = var.environment
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "instance_ids" {
  description = "EC2 instance IDs"
  value       = aws_instance.web[*].id
}

output "instance_private_ips" {
  description = "Private IP addresses"
  value       = aws_instance.web[*].private_ip
}

output "instance_public_ips" {
  description = "Public IP addresses (Elastic IPs for prod)"
  value       = local.is_production ? aws_eip.web[*].public_ip : aws_instance.web[*].public_ip
}

output "configuration_summary" {
  description = "Environment configuration summary"
  value = {
    environment       = var.environment
    instance_type     = local.instance_type
    instance_count    = local.instance_count
    volume_size       = local.volume_size
    monitoring        = local.enable_monitoring
    is_production     = local.is_production
    elastic_ips       = local.is_production
    cloudwatch_alarms = local.is_production
    ssh_enabled       = !local.is_production
  }
}

output "cost_estimate" {
  description = "Estimated resource counts"
  value = {
    ec2_instances     = local.instance_count
    elastic_ips       = local.is_production ? local.instance_count : 0
    cloudwatch_alarms = local.is_production ? local.instance_count : 0
    subnets           = 4
    security_groups   = 1
  }
}
