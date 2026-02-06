locals {
  # Common tags for all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
    CostCenter  = var.environment == "prod" ? "production" : "development"
  }
  
  # Environment-specific values using lookup
  instance_type     = lookup(var.instance_types, var.environment, "t3.micro")
  instance_count    = lookup(var.instance_counts, var.environment, 1)
  enable_monitoring = lookup(var.enable_monitoring, var.environment, false)
  volume_size       = lookup(var.volume_sizes, var.environment, 20)
  vpc_cidr          = lookup(var.vpc_cidrs, var.environment, "10.0.0.0/16")
  
  # Computed values
  name_prefix    = "${var.project_name}-${var.environment}"
  is_production  = var.environment == "prod"
  
  # Subnet calculations
  public_subnet_cidrs = [
    cidrsubnet(local.vpc_cidr, 8, 0),
    cidrsubnet(local.vpc_cidr, 8, 1)
  ]
  
  private_subnet_cidrs = [
    cidrsubnet(local.vpc_cidr, 8, 10),
    cidrsubnet(local.vpc_cidr, 8, 11)
  ]
  
  # Environment-specific resource counts
  nat_gateway_count = local.is_production ? 2 : 0
  db_instance_class = local.is_production ? "db.t3.medium" : "db.t3.micro"
  
  # Backup configuration
  backup_retention = local.is_production ? 30 : 7
}
