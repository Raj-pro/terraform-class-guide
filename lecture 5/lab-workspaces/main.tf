provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # us-east-1e can lack support for some instance families in some accounts.
  # Filter it out to keep this lab's applies reliable.
  az_names = var.aws_region == "us-east-1" ? [
    for az in data.aws_availability_zones.available.names : az if az != "us-east-1e"
  ] : data.aws_availability_zones.available.names
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# =============================================================================
# NETWORKING (shared across workspaces via state isolation)
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name        = "${terraform.workspace}-vpc"
    Environment = terraform.workspace
    ManagedBy   = "Terraform"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${terraform.workspace}-igw"
    Environment = terraform.workspace
    ManagedBy   = "Terraform"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${terraform.workspace}-public-rt"
    Environment = terraform.workspace
    ManagedBy   = "Terraform"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = local.az_names[0]

  tags = {
    Name        = "${terraform.workspace}-public-subnet"
    Environment = terraform.workspace
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web" {
  name        = "${terraform.workspace}-web-sg"
  description = "Security group for ${terraform.workspace} environment"
  vpc_id      = aws_vpc.main.id

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

  tags = {
    Name        = "${terraform.workspace}-web-sg"
    Environment = terraform.workspace
  }
}

# =============================================================================
# PART B: WORKSPACE-SPECIFIC VARIABLES (via locals map)
# =============================================================================

# EC2 instances - count and type based on workspace
resource "aws_instance" "web" {
  count = local.config.instance_count

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = local.config.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  monitoring             = local.config.enable_monitoring

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Workspace: ${terraform.workspace} - Server ${count.index + 1}</h1>" > /var/www/html/index.html
    echo "<p>Instance Type: ${local.config.instance_type}</p>" >> /var/www/html/index.html
    echo "<p>Monitoring: ${local.config.enable_monitoring}</p>" >> /var/www/html/index.html
  EOF

  tags = {
    Name        = "${terraform.workspace}-web-${count.index + 1}"
    Environment = terraform.workspace
    Workspace   = terraform.workspace
  }
}
