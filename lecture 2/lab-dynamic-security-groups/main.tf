provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
  
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Define all security groups with their rules
  security_groups = {
    web = {
      description   = "Security group for web servers"
      ingress_rules = var.web_ingress_rules
    }
    app = {
      description   = "Security group for application servers"
      ingress_rules = var.app_ingress_rules
    }
    db = {
      description   = "Security group for database servers"
      ingress_rules = var.db_ingress_rules
    }
  }
}

# Create security groups using for_each
resource "aws_security_group" "main" {
  for_each = local.security_groups
  
  name        = "${local.name_prefix}-${each.key}-sg"
  description = each.value.description
  vpc_id      = var.vpc_id
  
  # Dynamic ingress rules
  dynamic "ingress" {
    for_each = each.value.ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
  
  # Add SSH rule to web and app security groups
  dynamic "ingress" {
    for_each = contains(["web", "app"], each.key) ? [1] : []
    content {
      description = "SSH access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }
  
  # Default egress rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}-sg"
    Tier = each.key
  })
}

# Additional security group with port range
resource "aws_security_group" "ephemeral" {
  name        = "${local.name_prefix}-ephemeral-sg"
  description = "Security group for ephemeral port range"
  vpc_id      = var.vpc_id
  
  ingress {
    description = "Ephemeral ports for NLB"
    from_port   = 1024
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ephemeral-sg"
  })
}
