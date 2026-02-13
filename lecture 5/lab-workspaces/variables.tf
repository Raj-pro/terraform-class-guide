variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Workspace-specific configuration map
locals {
  workspace_config = {
    default = {
      instance_type     = "t3.micro"
      instance_count    = 1
      enable_monitoring = false
    }
    dev = {
      instance_type     = "t3.micro"
      instance_count    = 1
      enable_monitoring = false
    }
    staging = {
      instance_type     = "t3.small"
      instance_count    = 2
      enable_monitoring = true
    }
    prod = {
      instance_type     = "t3.medium"
      instance_count    = 3
      enable_monitoring = true
    }
  }

  # Get config for current workspace
  config = local.workspace_config[terraform.workspace]
}
