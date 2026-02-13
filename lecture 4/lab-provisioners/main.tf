provider "aws" {
  region = var.aws_region
}

# =============================================================================
# DATA SOURCES
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

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
}

# =============================================================================
# LOCALS
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# =============================================================================
# SSH KEY PAIR
# =============================================================================

resource "aws_key_pair" "deployer" {
  key_name   = "${local.name_prefix}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))

  tags = local.common_tags
}

# =============================================================================
# VPC RESOURCES
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public"
  })
}

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

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# =============================================================================
# SECURITY GROUP
# =============================================================================

resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "Security group for web server with provisioners"
  vpc_id      = aws_vpc.main.id

  # SSH for provisioners
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP for web server
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
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

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-sg"
  })
}

# =============================================================================
# EC2 INSTANCE WITH PROVISIONERS
# =============================================================================

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web"
  })

  # ==========================================================================
  # PROVISIONER 0: remote-exec - Create directories for file uploads
  # ==========================================================================
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
        private_key = file(pathexpand(var.ssh_private_key_path))
      host        = self.public_ip
      timeout     = "5m"
    }

    inline = [
      "mkdir -p /tmp/configs /tmp/scripts"
    ]
  }

  # ==========================================================================
  # PROVISIONER 1: file - Copy application config
  # ==========================================================================
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
        private_key = file(pathexpand(var.ssh_private_key_path))
      host        = self.public_ip
      timeout     = "5m"
    }

    source      = "${path.module}/configs/"
    destination = "/tmp/configs/"
  }

  # ==========================================================================
  # PROVISIONER 2: file - Copy setup scripts
  # ==========================================================================
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
        private_key = file(pathexpand(var.ssh_private_key_path))
      host        = self.public_ip
      timeout     = "5m"
    }

    source      = "${path.module}/scripts/"
    destination = "/tmp/scripts/"
  }

  # ==========================================================================
  # PROVISIONER 3: remote-exec - Install and configure application
  # ==========================================================================
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
        private_key = file(pathexpand(var.ssh_private_key_path))
      host        = self.public_ip
      timeout     = "5m"
    }

    inline = [
      "echo 'Starting server setup...'",

      # Make scripts executable
      "chmod +x /tmp/scripts/*.sh",

      # Run setup script
      "/tmp/scripts/setup.sh",

      # Move config files
      "sudo mkdir -p /etc/${var.app_name}",
      "sudo cp /tmp/configs/* /etc/${var.app_name}/",

      # Start the application
      "/tmp/scripts/start-app.sh",

      "echo 'Server setup complete!'"
    ]
  }

  # ==========================================================================
  # PROVISIONER 4: local-exec - Notify external system
  # ==========================================================================
  provisioner "local-exec" {
    command = "echo 'Instance ${self.id} deployed with IP ${self.public_ip}' >> deployment.log"
  }

  provisioner "local-exec" {
    command = "echo 'Deployment completed at $(date)' >> deployment.log"
  }

  # ==========================================================================
  # PROVISIONER 5: local-exec on destroy - Cleanup
  # ==========================================================================
  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Instance ${self.id} being destroyed at $(date)' >> deployment.log"
  }
}

# =============================================================================
# ELASTIC IP - For stable public IP
# =============================================================================

resource "aws_eip" "web" {
  instance = aws_instance.web.id
  domain   = "vpc"

  depends_on = [aws_internet_gateway.main]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-eip"
  })
}
