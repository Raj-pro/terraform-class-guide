# Provider Configuration
provider "aws" {
  region = "us-east-1"  # Change to your preferred region
}

# Random ID for unique bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket - Your cloud storage
resource "aws_s3_bucket" "lab_bucket" {
  bucket = "terraform-lab-bucket-${random_id.bucket_suffix.hex}"

  tags = {
    Name      = "Terraform-Lab-Bucket"
    CreatedBy = "Terraform"
  }
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

# EC2 Instance - Your server with S3 access
resource "aws_instance" "my_first_server" {
  ami                    = "ami-0c101f26f147fa7fd"  # Amazon Linux 2023
  instance_type          = "t3.micro"
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name      = "Terraform-Lab-Server"
    CreatedBy = "Terraform"
  }
}

# Outputs - Display important information
output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.my_first_server.id
}

output "instance_public_ip" {
  description = "Public IP of EC2 instance"
  value       = aws_instance.my_first_server.public_ip
}

output "s3_bucket_name" {
  description = "Name of S3 bucket"
  value       = aws_s3_bucket.lab_bucket.id
}
