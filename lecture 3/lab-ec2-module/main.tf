provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# =============================================================================
# SHARED VPC AND NETWORKING
# =============================================================================

resource "aws_vpc" "shared" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  
  tags = {
    Name = "shared-vpc"
  }
}

resource "aws_internet_gateway" "shared" {
  vpc_id = aws_vpc.shared.id
  
  tags = {
    Name = "shared-igw"
  }
}

# Dev subnet
resource "aws_subnet" "dev" {
  vpc_id                  = aws_vpc.shared.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  
  tags = {
    Name        = "dev-subnet"
    Environment = "dev"
  }
}

# Prod subnet
resource "aws_subnet" "prod" {
  vpc_id                  = aws_vpc.shared.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  
  tags = {
    Name        = "prod-subnet"
    Environment = "prod"
  }
}

# Dev security group
resource "aws_security_group" "dev" {
  name        = "dev-sg"
  description = "Dev environment security group"
  vpc_id      = aws_vpc.shared.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name        = "dev-sg"
    Environment = "dev"
  }
}

# Prod security group
resource "aws_security_group" "prod" {
  name        = "prod-sg"
  description = "Prod environment security group"
  vpc_id      = aws_vpc.shared.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name        = "prod-sg"
    Environment = "prod"
  }
}

# =============================================================================
# PART B: USE MODULE - DEV ENVIRONMENT (Single server)
# =============================================================================

module "dev_server" {
  source = "./modules/ec2"
  
  ami_id             = data.aws_ami.amazon_linux.id
  instance_type      = "t3.micro"
  subnet_id          = aws_subnet.dev.id
  security_group_ids = [aws_security_group.dev.id]
  instance_name      = "dev-web-server"
  environment        = "dev"
  
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Development Environment</h1>" > /var/www/html/index.html
    echo "<p>Instance Type: t3.micro</p>" >> /var/www/html/index.html
  EOF
  
  additional_tags = {
    CostCenter  = "development"
    Team        = "platform"
    Application = "web"
  }
}

# =============================================================================
# PART C: REUSE SAME MODULE - PROD ENVIRONMENT
# =============================================================================

module "prod_server" {
  source = "./modules/ec2"
  
  ami_id             = data.aws_ami.amazon_linux.id
  instance_type      = "t3.small"  # Larger instance for prod
  subnet_id          = aws_subnet.prod.id
  security_group_ids = [aws_security_group.prod.id]
  instance_name      = "prod-web-server"
  environment        = "prod"
  
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Production Environment</h1>" > /var/www/html/index.html
    echo "<p>Instance Type: t3.small</p>" >> /var/www/html/index.html
  EOF
  
  additional_tags = {
    CostCenter  = "production"
    Team        = "platform"
    Compliance  = "required"
    Monitoring  = "enabled"
  }
}
