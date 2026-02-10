provider "aws" {
  region = var.aws_region
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "aws_caller_identity" "current" {}

# =============================================================================
# PART A: IMPORT - Resource to import into (initially empty, filled after import)
# =============================================================================

# Uncomment after creating a manual instance in AWS Console
# resource "aws_instance" "imported" {
#   ami           = "ami-0c101f26f147fa7fd"
#   instance_type = "t3.micro"
#   
#   tags = {
#     Name      = "manual-instance"
#     ManagedBy = "Terraform"
#   }
# }

# =============================================================================
# PART B: LIFECYCLE RULES
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "lifecycle-demo-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "lifecycle-demo-subnet"
  }
}

resource "aws_security_group" "web" {
  name   = "lifecycle-demo-sg"
  vpc_id = aws_vpc.main.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Example 1: create_before_destroy
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    echo "<h1>Zero Downtime Update</h1>" > /var/www/html/index.html
  EOF
  
  tags = {
    Name = "web-server"
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Example 2: prevent_destroy
resource "aws_s3_bucket" "critical_data" {
  bucket = "lifecycle-demo-critical-${data.aws_caller_identity.current.account_id}"
  
  tags = {
    Name     = "Critical Data Bucket"
    Critical = "true"
  }
  
  lifecycle {
    prevent_destroy = true
  }
}

# Example 3: ignore_changes
resource "aws_instance" "external_managed" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  
  tags = {
    Name        = "external-managed"
    Environment = "dev"
  }
  
  lifecycle {
    ignore_changes = [
      tags["Environment"],  # External system manages this tag
    ]
  }
}

# =============================================================================
# PART C: CI/CD DEMO RESOURCE
# =============================================================================

resource "aws_instance" "cicd_demo" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  
  tags = {
    Name      = "cicd-demo"
    ManagedBy = "Terraform"
    Pipeline  = "GitHub-Actions"
  }
}
