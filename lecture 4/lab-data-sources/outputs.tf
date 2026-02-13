# =============================================================================
# DATA SOURCE OUTPUTS
# =============================================================================

output "account_id" {
  description = "Current AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "Current AWS region"
  value       = data.aws_region.current.name
}

output "availability_zones" {
  description = "Available availability zones"
  value       = data.aws_availability_zones.available.names
}

output "ami_id" {
  description = "Amazon Linux AMI ID used"
  value       = data.aws_ami.amazon_linux.id
}

output "ami_name" {
  description = "Amazon Linux AMI name"
  value       = data.aws_ami.amazon_linux.name
}

# =============================================================================
# VPC OUTPUTS
# =============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

# =============================================================================
# SUBNET OUTPUTS
# =============================================================================

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  value       = aws_subnet.private[*].cidr_block
}

# =============================================================================
# GATEWAY OUTPUTS
# =============================================================================

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[0].id : null
}

output "nat_gateway_public_ip" {
  description = "NAT Gateway public IP"
  value       = var.enable_nat_gateway ? aws_eip.nat[0].public_ip : null
}

# =============================================================================
# EC2 OUTPUTS
# =============================================================================

output "instance_ids" {
  description = "EC2 instance IDs"
  value       = aws_instance.web[*].id
}

output "instance_public_ips" {
  description = "EC2 public IP addresses"
  value       = aws_instance.web[*].public_ip
}

output "instance_private_ips" {
  description = "EC2 private IP addresses"
  value       = aws_instance.web[*].private_ip
}

# =============================================================================
# SUMMARY
# =============================================================================

output "infrastructure_summary" {
  description = "Summary of created infrastructure"
  value = {
    account         = data.aws_caller_identity.current.account_id
    region          = data.aws_region.current.name
    vpc_id          = aws_vpc.main.id
    public_subnets  = length(aws_subnet.public)
    private_subnets = length(aws_subnet.private)
    instances       = length(aws_instance.web)
    nat_enabled     = var.enable_nat_gateway
  }
}
