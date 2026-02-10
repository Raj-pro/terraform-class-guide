# Lecture 3: Provisioners, Data Sources and Dependencies

This lecture covers how Terraform interacts with existing infrastructure through data sources, manages resource creation order through dependencies, and executes scripts through provisioners. By the end of this session, students will understand how to build infrastructure that integrates with existing resources and configures itself after creation.

---

# Part 1: Theory

## Section 1: Data Sources

### Why Data Sources Matter

Every real-world infrastructure project exists within a larger ecosystem. You inherit existing VPCs created by another team. You need the latest AMI IDs that change monthly. You must deploy to specific availability zones based on your region.

Without data sources, you would hardcode these values. When the AMI ID changes, your configuration breaks. When the network team updates the VPC, your subnets fail to create. You spend hours tracking down outdated values.

Data sources solve this problem. They query your cloud provider at runtime and return current values. Your configuration stays dynamic and self-correcting. The AMI ID always points to the latest version. The VPC ID always matches the current infrastructure.

### Data Sources vs Resources

Understanding the difference between data sources and resources is fundamental to Terraform.

Resources create, update, and destroy infrastructure. When you define an aws_instance resource, Terraform creates an EC2 instance. When you change the configuration, Terraform updates or recreates it. When you remove the resource, Terraform destroys the instance.

Data sources only read. They query existing infrastructure and return information. They never create, modify, or destroy anything. They are read-only windows into your cloud environment.

```hcl
# Resource - CREATES an EC2 instance
resource "aws_instance" "web" {
  ami           = "ami-0c101f26f147fa7fd"
  instance_type = "t3.micro"
}

# Data source - READS an existing EC2 instance
data "aws_instance" "existing" {
  instance_id = "i-0abc123def456789"
}

# Use the data source to get information
output "existing_instance_ip" {
  value = data.aws_instance.existing.public_ip
}
```

### Common Data Sources

### Fetching the Latest AMI

One of the most common data source use cases is finding the latest Amazon Machine Image. AMI IDs change frequently and vary by region.

```hcl
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

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
}
```

The filter blocks narrow down the search. The most_recent flag ensures you always get the latest matching AMI. When Amazon releases a new AMI, your next terraform apply automatically picks it up.

### Fetching Availability Zones

Availability zones vary by region and account. Some accounts have access to zones that others do not. Data sources ensure you only use zones available to you.

```hcl
data "aws_availability_zones" "available" {
  state = "available"
}

output "zones" {
  value = data.aws_availability_zones.available.names
}

# Use zones dynamically
resource "aws_subnet" "public" {
  count             = length(data.aws_availability_zones.available.names)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
}
```

### Referencing Existing VPCs

Your team creates a shared VPC that multiple projects use. Instead of recreating it, reference it with a data source.

```hcl
# Fetch existing VPC by tag
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Name"
    values = ["shared-vpc"]
  }
}

# Fetch subnets in that VPC
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  
  filter {
    name   = "tag:Tier"
    values = ["private"]
  }
}

# Create resources in the existing VPC
resource "aws_instance" "app" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  subnet_id     = data.aws_subnets.private.ids[0]
}
```

### Fetching Current AWS Account and Region

```hcl
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

output "account_info" {
  value = "Account: ${local.account_id}, Region: ${local.region}"
}
```

### Reading IAM Policies

```hcl
data "aws_iam_policy_document" "s3_read" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.data.arn,
      "${aws_s3_bucket.data.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "s3_read" {
  name   = "s3-read-policy"
  policy = data.aws_iam_policy_document.s3_read.json
}
```

---

## Section 2: Dependencies

### Why Dependencies Matter

Cloud infrastructure has a natural order. You cannot create a subnet before the VPC exists. You cannot attach a security group to an instance if the security group does not exist yet.

Terraform handles most of this automatically through implicit dependencies. When you reference one resource in another, Terraform knows to create the referenced resource first.

But some dependencies are not visible in your code. A NAT gateway needs the internet gateway to be fully attached before it can route traffic. A load balancer health check needs the application to be running. These invisible dependencies cause race conditions and intermittent failures.

Understanding both implicit and explicit dependencies prevents deployment failures and makes your infrastructure reliable.

### Implicit Dependencies

Implicit dependencies are created automatically when you reference one resource in another. Terraform analyzes your configuration and builds a dependency graph.

```hcl
# VPC is created first (no dependencies)
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Subnet depends on VPC (referenced via aws_vpc.main.id)
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
}

# Instance depends on subnet (referenced via aws_subnet.public.id)
resource "aws_instance" "web" {
  subnet_id = aws_subnet.public.id
  ami       = "ami-0c101f26f147fa7fd"
  instance_type = "t3.micro"
}
```

Terraform builds this dependency chain:
1. Create VPC
2. Create Subnet (after VPC)
3. Create Instance (after Subnet)

You never specified this order. Terraform inferred it from your references.

### Viewing the Dependency Graph

Terraform can generate a visual dependency graph:

```bash
terraform graph | dot -Tpng > graph.png
```

This shows exactly how Terraform will order resource creation.

### Explicit Dependencies with depends_on

Some dependencies cannot be inferred from references. The depends_on meta-argument creates explicit dependencies for these cases.

### When You Need depends_on

Use depends_on when:

1. Resources have no direct reference but still depend on each other
2. Timing matters beyond what references capture
3. External systems need time to propagate changes

### Example: NAT Gateway and Internet Gateway

A NAT gateway requires the internet gateway to be fully attached to the VPC. Simply referencing the VPC is not enough.

```hcl
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
  
  # Explicit dependency - EIP needs IGW attached first
  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  
  # Explicit dependency - NAT needs IGW for internet access
  depends_on = [aws_internet_gateway.main]
}
```

### Example: IAM Role and Policy Attachment

```hcl
resource "aws_iam_role" "app" {
  name = "app-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "app_s3" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "app" {
  name = "app-profile"
  role = aws_iam_role.app.name
}

resource "aws_instance" "app" {
  ami                  = data.aws_ami.amazon_linux.id
  instance_type        = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.app.name
  
  # Wait for policy to be attached before launching
  depends_on = [aws_iam_role_policy_attachment.app_s3]
}
```

### Dependency Best Practices

1. Prefer implicit dependencies when possible. They are self-documenting and less error-prone.
2. Use depends_on only when necessary. Overusing it creates unnecessary ordering constraints.
3. Document why explicit dependencies exist. Future maintainers need to understand the reason.

```hcl
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  
  # The NAT gateway needs the internet gateway to be fully attached
  # to the VPC before it can route traffic to the internet.
  # This cannot be inferred from resource references alone.
  depends_on = [aws_internet_gateway.main]
}
```

---

## Section 3: Provisioners

### Why Provisioners Exist

Terraform excels at creating infrastructure. But infrastructure alone is not enough. A freshly created EC2 instance is just an empty server. It needs software installed, configuration files written, and services started.

Provisioners bridge this gap. They execute scripts and commands after resources are created. They transform empty servers into functioning applications.

However, provisioners come with significant tradeoffs. They run outside Terraform's normal workflow. They can fail without Terraform knowing how to recover. They make your infrastructure less reproducible.

Understanding when to use provisioners and when to avoid them is crucial for production-ready infrastructure.

### Types of Provisioners

Terraform provides three built-in provisioners:

1. local-exec: Runs commands on the machine running Terraform
2. remote-exec: Runs commands on the created resource via SSH or WinRM
3. file: Copies files to the created resource

### The local-exec Provisioner

local-exec runs commands on your local machine where Terraform is executing. It is useful for:

- Triggering external systems after resource creation
- Running local scripts that configure other services
- Generating local files based on created resources

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  
  provisioner "local-exec" {
    command = "echo 'Instance ${self.id} created with IP ${self.public_ip}'"
  }
}
```

### local-exec with Environment Variables

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  
  provisioner "local-exec" {
    command = "./scripts/register-instance.sh"
    
    environment = {
      INSTANCE_ID = self.id
      INSTANCE_IP = self.public_ip
      ENVIRONMENT = var.environment
    }
  }
}
```

### local-exec with Different Interpreters

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  
  # Run Python script
  provisioner "local-exec" {
    command     = "process_instance.py ${self.id}"
    interpreter = ["python3", "-c"]
  }
  
  # Run PowerShell on Windows
  provisioner "local-exec" {
    command     = "Register-Instance -Id ${self.id}"
    interpreter = ["PowerShell", "-Command"]
  }
}
```

### The remote-exec Provisioner

remote-exec runs commands on the created resource via SSH or WinRM. It requires a connection block to establish the connection.

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.deployer.key_name
  
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y httpd",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd"
    ]
  }
}
```

### remote-exec with Script File

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.deployer.key_name
  
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip
  }
  
  provisioner "remote-exec" {
    script = "${path.module}/scripts/setup.sh"
  }
}
```

### The file Provisioner

The file provisioner copies files or directories from the local machine to the created resource.

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.deployer.key_name
  
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip
  }
  
  # Copy a single file
  provisioner "file" {
    source      = "configs/app.conf"
    destination = "/tmp/app.conf"
  }
  
  # Copy a directory
  provisioner "file" {
    source      = "scripts/"
    destination = "/home/ec2-user/scripts"
  }
  
  # Copy inline content
  provisioner "file" {
    content     = "DATABASE_URL=${aws_db_instance.main.endpoint}"
    destination = "/tmp/env.conf"
  }
  
  # Now run setup
  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/app.conf /etc/app/app.conf",
      "chmod +x /home/ec2-user/scripts/*.sh",
      "/home/ec2-user/scripts/setup.sh"
    ]
  }
}
```

### Connection Blocks

Connection blocks configure how Terraform connects to resources for remote-exec and file provisioners.

### SSH Connection

```hcl
connection {
  type        = "ssh"
  user        = "ec2-user"
  private_key = file("~/.ssh/id_rsa")
  host        = self.public_ip
  port        = 22
  timeout     = "5m"
}
```

### SSH with Bastion Host

```hcl
connection {
  type        = "ssh"
  user        = "ec2-user"
  private_key = file("~/.ssh/id_rsa")
  host        = self.private_ip
  
  bastion_host        = aws_instance.bastion.public_ip
  bastion_user        = "ec2-user"
  bastion_private_key = file("~/.ssh/id_rsa")
}
```

### WinRM Connection for Windows

```hcl
connection {
  type     = "winrm"
  user     = "Administrator"
  password = var.admin_password
  host     = self.public_ip
  port     = 5986
  https    = true
  insecure = true
  timeout  = "10m"
}
```

---

## Section 4: Provisioner Behavior

### Creation-Time vs Destroy-Time Provisioners

By default, provisioners run when the resource is created. You can also run provisioners when the resource is destroyed.

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  
  # Runs when instance is created
  provisioner "local-exec" {
    command = "./scripts/register.sh ${self.id}"
  }
  
  # Runs when instance is destroyed
  provisioner "local-exec" {
    when    = destroy
    command = "./scripts/deregister.sh ${self.id}"
  }
}
```

### Handling Provisioner Failures

By default, if a provisioner fails, the resource is marked as tainted and will be recreated on the next apply. You can change this behavior.

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  
  provisioner "remote-exec" {
    # Continue even if provisioner fails
    on_failure = continue
    
    inline = [
      "sudo yum update -y"
    ]
  }
  
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip
  }
}
```

### Multiple Provisioners

You can have multiple provisioners on a single resource. They run in order.

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.deployer.key_name
  
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip
  }
  
  # Step 1: Copy configuration files
  provisioner "file" {
    source      = "configs/"
    destination = "/tmp/configs"
  }
  
  # Step 2: Copy setup scripts
  provisioner "file" {
    source      = "scripts/"
    destination = "/tmp/scripts"
  }
  
  # Step 3: Run setup
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/scripts/*.sh",
      "/tmp/scripts/install.sh",
      "/tmp/scripts/configure.sh",
      "/tmp/scripts/start.sh"
    ]
  }
  
  # Step 4: Notify local systems
  provisioner "local-exec" {
    command = "curl -X POST https://api.example.com/notify -d 'instance=${self.id}'"
  }
}
```

---

## Section 5: When to Use and Avoid Provisioners

### The Case Against Provisioners

HashiCorp explicitly recommends treating provisioners as a last resort. Here is why:

1. Provisioners break the declarative model. Terraform cannot detect drift in provisioned configurations.

2. Provisioners are not idempotent. Running the same script twice may produce different results.

3. Provisioners increase failure points. Network issues, SSH timeouts, and script errors can fail deployments.

4. Provisioners make testing harder. You cannot plan what a script will do.

### Better Alternatives

### Use Cloud-Init or User Data Instead

User data scripts run at instance boot without requiring SSH access.

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello from ${var.environment}</h1>" > /var/www/html/index.html
  EOF
}
```

### Use Configuration Management Tools

For complex configurations, use tools designed for the job:

- Ansible for procedural configuration
- Chef or Puppet for desired state configuration
- Packer for building pre-configured AMIs

```hcl
# Use a pre-built AMI instead of provisioners
data "aws_ami" "app" {
  most_recent = true
  owners      = ["self"]
  
  filter {
    name   = "name"
    values = ["my-app-*"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.app.id
  instance_type = "t3.micro"
  # No provisioners needed - AMI is pre-configured
}
```

### When Provisioners Are Appropriate

Provisioners are appropriate when:

1. You need to run a one-time initialization that cannot be in user_data
2. You must integrate with external systems immediately after creation
3. You need to pass runtime values that are not available at boot
4. You are bootstrapping configuration management (running Ansible for the first time)

```hcl
# Appropriate: Bootstrap Ansible
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  
  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' playbook.yml"
  }
}

# Appropriate: Register with external service
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  
  provisioner "local-exec" {
    command = "vault write secret/instances/${self.id} ip=${self.public_ip}"
  }
}
```

---

# Part 2: Practice

## Lab Overview

This section contains two comprehensive labs that cover all concepts from the theory.

| Lab | Topic | Duration |
|-----|-------|----------|
| Lab 1 | Data Sources and Dependencies | 45 min |
| Lab 2 | Provisioners and Application Deployment | 45 min |

---

## Lab 1: Data Sources and Dependencies

### Directory

lab-data-sources/

### Objective

Build infrastructure that queries existing resources dynamically and manages dependencies correctly. This lab demonstrates data sources for AMIs and availability zones, implicit dependencies, and explicit depends_on.

### Key Concepts Demonstrated

- Fetching AMI IDs dynamically
- Querying availability zones
- Building implicit dependency chains
- Using explicit depends_on for timing
- Referencing account and region information

### Resources Created

- VPC with dynamic availability zone subnets
- Internet Gateway with proper dependencies
- NAT Gateway with explicit dependency
- EC2 instances using dynamic AMI
- Security groups with proper ordering

### Commands

```bash
cd lab-data-sources
terraform init
terraform plan
terraform apply

# View dependency graph
terraform graph > graph.dot

# Cleanup
terraform destroy
```

---

## Lab 2: Provisioners and Application Deployment

### Directory

lab-provisioners/

### Objective

Deploy a web application using provisioners to configure the server after creation. This lab demonstrates local-exec, remote-exec, file provisioners, and connection blocks.

### Key Concepts Demonstrated

- SSH key pair creation
- Connection blocks for remote access
- file provisioner for copying configurations
- remote-exec for server setup
- local-exec for external notifications
- Proper provisioner ordering
- Error handling with on_failure

### Resources Created

- SSH key pair for access
- VPC with public subnet
- Security group allowing SSH and HTTP
- EC2 instance with provisioners
- Web server installation and configuration

### Commands

```bash
cd lab-provisioners
terraform init
terraform plan
terraform apply

# Test the web server
curl http://$(terraform output -raw public_ip)

# Cleanup
terraform destroy
```

---

# Summary

## Key Concepts

| Concept | Purpose | Example |
|---------|---------|---------|
| Data Sources | Read existing infrastructure | data.aws_ami.amazon_linux |
| Implicit Dependencies | Automatic ordering from references | subnet_id = aws_subnet.public.id |
| Explicit Dependencies | Manual ordering when needed | depends_on = [aws_internet_gateway.main] |
| local-exec | Run local commands | command = "./scripts/notify.sh" |
| remote-exec | Run commands on resource | inline = ["yum install httpd"] |
| file | Copy files to resource | source = "configs/", destination = "/tmp" |
| Connection | Configure SSH/WinRM access | type = "ssh", user = "ec2-user" |

## Provisioner Decision Tree

1. Can the configuration be baked into an AMI? Use Packer.
2. Can it run at boot time? Use user_data.
3. Does it need runtime values from Terraform? Consider provisioners or configuration management.
4. Is it a one-time setup? local-exec to trigger Ansible may be appropriate.
5. None of the above? Provisioners as last resort.

## Next Steps

After completing this lecture, students should:

- Practice with more complex data source queries
- Explore Packer for building custom AMIs
- Learn Ansible integration with Terraform
- Study Terraform workspaces for environment management
