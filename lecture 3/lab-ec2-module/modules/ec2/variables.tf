variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID for the instance"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where instance will be created"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
  default     = []
}

variable "instance_name" {
  description = "Name tag for the instance"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "additional_tags" {
  description = "Additional tags for the instance"
  type        = map(string)
  default     = {}
}

variable "user_data" {
  description = "User data script"
  type        = string
  default     = ""
}
