variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "owner" {
  description = "Owner email"
  type        = string
}

# Environment-specific configurations as maps
variable "instance_types" {
  description = "Instance types per environment"
  type        = map(string)
  default = {
    dev     = "t3.micro"
    staging = "t3.small"
    prod    = "t3.medium"
  }
}

variable "instance_counts" {
  description = "Instance counts per environment"
  type        = map(number)
  default = {
    dev     = 1
    staging = 2
    prod    = 3
  }
}

variable "enable_monitoring" {
  description = "Enable monitoring per environment"
  type        = map(bool)
  default = {
    dev     = false
    staging = true
    prod    = true
  }
}

variable "volume_sizes" {
  description = "EBS volume sizes per environment"
  type        = map(number)
  default = {
    dev     = 20
    staging = 50
    prod    = 100
  }
}

variable "enable_backup" {
  description = "Enable backup (only for prod)"
  type        = bool
  default     = false
}

variable "vpc_cidrs" {
  description = "VPC CIDR blocks per environment"
  type        = map(string)
  default = {
    dev     = "10.0.0.0/16"
    staging = "10.1.0.0/16"
    prod    = "10.2.0.0/16"
  }
}
