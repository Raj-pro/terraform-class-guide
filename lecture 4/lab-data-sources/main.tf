provider "aws" {
  region = var.aws_region
}

# =============================================================================
# DATA SOURCES - Query existing/dynamic information
# =============================================================================

# Fetch current AWS account information
data "aws_caller_identity" "current" {}

# Fetch current region
data "aws_region" "current" {}

# Fetch available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Fetch the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# =============================================================================
# LOCALS - Computed values using data sources
# =============================================================================

locals {
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.name
  name_prefix = "${var.project_name}-${var.environment}"

  # Use data source to get AZs dynamically
  azs = slice(data.aws_availability_zones.available.names, 0, max(var.public_subnet_count, var.private_subnet_count))

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    AccountId   = local.account_id
  }
}

# =============================================================================
# VPC - Foundation resource (no dependencies)
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# =============================================================================
# INTERNET GATEWAY - Implicit dependency on VPC
# =============================================================================

resource "aws_internet_gateway" "main" {
  # Implicit dependency: references aws_vpc.main.id
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# =============================================================================
# SUBNETS - Implicit dependency on VPC, using data sources for AZs
# =============================================================================

resource "aws_subnet" "public" {
  count = var.public_subnet_count

  # Implicit dependency on VPC
  vpc_id = aws_vpc.main.id

  # Using data source for availability zones
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)

  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${count.index + 1}"
    Tier = "Public"
    AZ   = local.azs[count.index]
  })
}

resource "aws_subnet" "private" {
  count = var.private_subnet_count

  vpc_id            = aws_vpc.main.id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${count.index + 1}"
    Tier = "Private"
    AZ   = local.azs[count.index]
  })
}

# =============================================================================
# ELASTIC IP for NAT - Explicit dependency on IGW
# =============================================================================

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  # EXPLICIT DEPENDENCY: The EIP needs the IGW to be fully attached
  # before it can be used for NAT gateway
  depends_on = [aws_internet_gateway.main]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-eip"
  })
}

# =============================================================================
# NAT GATEWAY - Explicit dependency on IGW
# =============================================================================

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  # EXPLICIT DEPENDENCY: NAT gateway needs IGW for internet connectivity
  # This cannot be inferred from references alone
  depends_on = [aws_internet_gateway.main]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat"
  })
}

# =============================================================================
# ROUTE TABLES - Multiple dependencies
# =============================================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-rt"
  })
}

resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

resource "aws_route_table_association" "public" {
  count = var.public_subnet_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = var.private_subnet_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# =============================================================================
# SECURITY GROUP - Uses VPC reference
# =============================================================================

resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-sg"
  })
}

# =============================================================================
# EC2 INSTANCES - Uses data source for AMI, multiple dependencies
# =============================================================================

resource "aws_instance" "web" {
  count = var.instance_count

  # Using data source for dynamic AMI lookup
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  # Distribute across public subnets
  subnet_id = aws_subnet.public[count.index % var.public_subnet_count].id

  # Implicit dependency on security group
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello from ${local.name_prefix}-web-${count.index + 1}</h1>" > /var/www/html/index.html
    echo "<p>Instance: $(hostname)</p>" >> /var/www/html/index.html
    echo "<p>AZ: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>" >> /var/www/html/index.html
  EOF

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-${count.index + 1}"
    Role = "WebServer"
  })
}
