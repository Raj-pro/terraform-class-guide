# Provider Configuration
provider "aws" {
  region = "us-east-1"  # Change to your preferred region
}

# VPC - Your Private Network
resource "aws_vpc" "lab_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "Terraform-Lab-VPC"
    CreatedBy = "Terraform"
  }
}

# Internet Gateway - Connects VPC to Internet
resource "aws_internet_gateway" "lab_igw" {
  vpc_id = aws_vpc.lab_vpc.id

  tags = {
    Name      = "Terraform-Lab-IGW"
    CreatedBy = "Terraform"
  }
}

# Subnet - A segment within your VPC
resource "aws_subnet" "lab_subnet" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name      = "Terraform-Lab-Subnet"
    CreatedBy = "Terraform"
  }
}

# Route Table - Defines network traffic rules
resource "aws_route_table" "lab_rt" {
  vpc_id = aws_vpc.lab_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab_igw.id
  }

  tags = {
    Name      = "Terraform-Lab-RouteTable"
    CreatedBy = "Terraform"
  }
}

# Route Table Association - Links subnet to route table
resource "aws_route_table_association" "lab_rta" {
  subnet_id      = aws_subnet.lab_subnet.id
  route_table_id = aws_route_table.lab_rt.id
}

# Security Group - Firewall rules for EC2
resource "aws_security_group" "lab_sg" {
  name        = "terraform-lab-sg"
  description = "Security group for Terraform lab EC2"
  vpc_id      = aws_vpc.lab_vpc.id

  # Allow SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Warning: Open to all IPs - restrict in production
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "Terraform-Lab-SG"
    CreatedBy = "Terraform"
  }
}

# S3 Bucket - Your cloud storage
resource "aws_s3_bucket" "lab_bucket" {
  bucket = "terraform-lab-bucket-${random_id.bucket_suffix.hex}"

  tags = {
    Name      = "Terraform-Lab-Bucket"
    CreatedBy = "Terraform"
  }
}

# Random ID for unique bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# IAM Role for EC2 to access S3
resource "aws_iam_role" "ec2_s3_role" {
  name = "terraform-lab-ec2-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name      = "Terraform-Lab-EC2-Role"
    CreatedBy = "Terraform"
  }
}

# IAM Policy for S3 access
resource "aws_iam_role_policy" "ec2_s3_policy" {
  name = "terraform-lab-s3-access"
  role = aws_iam_role.ec2_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.lab_bucket.arn,
          "${aws_s3_bucket.lab_bucket.arn}/*"
        ]
      }
    ]
  })
}

# IAM Instance Profile - Attaches role to EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "terraform-lab-ec2-profile"
  role = aws_iam_role.ec2_s3_role.name
}

# EC2 Instance - Your server in the VPC with S3 access
resource "aws_instance" "my_first_server" {
  ami                    = "ami-0c101f26f147fa7fd"  # Amazon Linux 2023
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.lab_subnet.id
  vpc_security_group_ids = [aws_security_group.lab_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name      = "Terraform-Lab-Server"
    CreatedBy = "Terraform"
  }
}

# Outputs - Display important information
output "instance_public_ip" {
  description = "Public IP of EC2 instance"
  value       = aws_instance.my_first_server.public_ip
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.lab_vpc.id
}

output "s3_bucket_name" {
  description = "Name of S3 bucket"
  value       = aws_s3_bucket.lab_bucket.id
}
