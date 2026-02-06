locals {
  # Common tags for all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
  
  # Naming prefix
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Get available AZs
  azs = slice(data.aws_availability_zones.available.names, 0, max(var.public_subnet_count, var.private_subnet_count))
  
  # Calculate subnet CIDRs using cidrsubnet function
  # Public subnets: 10.0.0.0/24, 10.0.1.0/24, 10.0.2.0/24
  public_subnet_cidrs = [
    for i in range(var.public_subnet_count) : cidrsubnet(var.vpc_cidr, 8, i)
  ]
  
  # Private subnets: 10.0.10.0/24, 10.0.11.0/24, 10.0.12.0/24
  private_subnet_cidrs = [
    for i in range(var.private_subnet_count) : cidrsubnet(var.vpc_cidr, 8, i + 10)
  ]
}
