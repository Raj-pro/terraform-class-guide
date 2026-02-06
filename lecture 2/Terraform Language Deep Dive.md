# Lecture 2: Terraform Language Deep Dive

This lecture covers the HashiCorp Configuration Language (HCL) syntax, variables, functions, loops, and expressions. By the end of this session, students will understand how to build real AWS infrastructure using parameterized, reusable configurations.

---

# Part 1: Theory

## Section 1: HCL Syntax and Structure

### Why HCL Matters

Every infrastructure team faces the same challenge: how do you describe complex cloud resources in a way that is both human-readable and machine-executable?

Consider the alternatives. JSON is the universal data format, but try writing a 500-line JSON file without making a syntax error. One missing comma breaks everything. YAML improves readability but lacks the expressiveness for complex logic. You cannot write conditionals or loops in YAML.

HCL was designed specifically to solve this problem. HashiCorp created it for Terraform, and it has since been adopted across their entire product suite. HCL gives you the readability of a configuration file with the power of a programming language.

When you write HCL, you are writing a specification that Terraform can execute, version, and reproduce exactly. This is the foundation of Infrastructure as Code.

### The Building Blocks

Every Terraform configuration is built from three fundamental elements: blocks, arguments, and expressions.

Understanding these building blocks is like understanding the grammar of a language. Once you internalize them, reading and writing Terraform becomes natural.

### Blocks

A block is a container that holds configuration. Every resource, provider, and variable you create is a block.

```hcl
# Block structure
block_type "label1" "label2" {
  # Block body contains arguments
  argument = value
}
```

The block type tells Terraform what kind of thing you are defining. Labels identify the specific instance. The body contains the configuration.

### Common Block Types

```hcl
# Provider block - configures cloud credentials and region
provider "aws" {
  region = "us-east-1"
}

# Resource block - creates actual infrastructure
resource "aws_instance" "web" {
  ami           = "ami-0c101f26f147fa7fd"
  instance_type = "t3.micro"
}

# Variable block - accepts input from outside
variable "instance_type" {
  type    = string
  default = "t3.micro"
}

# Output block - exposes values for display or other modules
output "instance_id" {
  value = aws_instance.web.id
}

# Locals block - defines computed values
locals {
  name_prefix = "myapp-prod"
}

# Data block - reads existing infrastructure
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
}
```

### Arguments and Expressions

Arguments assign values inside blocks. The left side is the argument name, the right side is the value or expression.

```hcl
resource "aws_instance" "example" {
  # Simple literal argument
  instance_type = "t3.micro"
  
  # Reference to another resource
  subnet_id = aws_subnet.main.id
  
  # Reference to a variable
  ami = var.ami_id
  
  # Expression using string interpolation
  tags = {
    Name = "Server-${var.environment}"
  }
  
  # Expression using a function
  user_data = file("scripts/bootstrap.sh")
  
  # Conditional expression
  monitoring = var.environment == "production" ? true : false
}
```

Expressions are the right side of arguments. They can be simple literal values, references to other resources, function calls, or complex calculations.

---

## Section 2: Variables

### The Problem Variables Solve

Imagine you are the infrastructure lead at a growing startup. You have three environments: development, staging, and production. Each environment needs the same resources but with different configurations. Development uses small instances, production uses large ones. Development has one server, production has five.

Without variables, you would copy-paste your Terraform configuration three times. When you need to add a new security group rule, you update three files. When you miss one, production breaks at 3 AM.

Variables solve this problem. You write the infrastructure logic once and inject different values for each environment. One codebase, multiple configurations.

### Input Variables

Input variables are the parameters of your Terraform configuration. They accept values from outside your code.

```hcl
variable "instance_type" {
  description = "EC2 instance type for the web servers"
  type        = string
  default     = "t3.micro"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 1
}
```

The description helps other team members understand what the variable is for. The type ensures only valid values are accepted. The default provides a fallback when no value is specified.

### Variable Types

Terraform supports several data types. Choosing the right type makes your code clearer and catches errors early.

### Primitive Types

```hcl
# String - text values
variable "region" {
  type    = string
  default = "us-east-1"
}

# Number - integers or decimals
variable "instance_count" {
  type    = number
  default = 2
}

# Boolean - true or false
variable "enable_monitoring" {
  type    = bool
  default = true
}
```

### Collection Types

```hcl
# List - ordered sequence of values
variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# Map - key-value pairs
variable "instance_types" {
  type = map(string)
  default = {
    dev     = "t3.micro"
    staging = "t3.small"
    prod    = "t3.large"
  }
}

# Set - unordered unique values
variable "allowed_cidrs" {
  type    = set(string)
  default = ["10.0.0.0/8", "172.16.0.0/12"]
}
```

### Structural Types

```hcl
# Object - fixed structure with named attributes
variable "server_config" {
  type = object({
    instance_type = string
    disk_size     = number
    enable_public = bool
  })
  default = {
    instance_type = "t3.micro"
    disk_size     = 20
    enable_public = true
  }
}

# Tuple - fixed length sequence with specific types
variable "database_config" {
  type = tuple([string, number, bool])
  default = ["db.t3.micro", 100, true]
}
```

### Variable Validation

Validation rules catch mistakes before Terraform creates resources. This prevents costly errors and wasted time.

Consider a variable for environment name. Without validation, someone might typo "prod" as "pord" and create resources with wrong tags. With validation, Terraform stops immediately with a clear error message.

```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  
  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

variable "owner_email" {
  description = "Email of the resource owner"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.owner_email))
    error_message = "Owner must be a valid email address."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}
```

---

## Section 3: Variable Precedence

### Why Precedence Matters

Every production Terraform deployment uses variables from multiple sources. Developers set local defaults. CI/CD pipelines inject environment-specific values. Emergency fixes require command-line overrides.

Understanding variable precedence prevents surprises. When the same variable is set in multiple places, which value wins?

### Precedence Order

Variables are evaluated in this order, with later sources overriding earlier ones:

1. Default values in variable definition (lowest priority)
2. Environment variables (TF_VAR_name)
3. terraform.tfvars file (auto-loaded)
4. terraform.tfvars.json file (auto-loaded)
5. Any *.auto.tfvars files (alphabetical order)
6. -var-file flag on command line
7. -var flag on command line (highest priority)

### Demonstration

Consider a variable defined with a default:

```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}
```

Now observe how different sources override each other:

```bash
# 1. Using default value (lowest priority)
terraform plan
# Result: environment = "dev"

# 2. Environment variable overrides default
export TF_VAR_environment="staging"
terraform plan
# Result: environment = "staging"

# 3. terraform.tfvars overrides environment variable
# File contains: environment = "uat"
terraform plan
# Result: environment = "uat"

# 4. -var-file overrides terraform.tfvars
terraform plan -var-file="prod.tfvars"
# Result: environment = "prod"

# 5. -var flag overrides everything (highest priority)
terraform plan -var="environment=test"
# Result: environment = "test"
```

### Practical Team Workflow

Your team uses terraform.tfvars for default development settings:

```hcl
# terraform.tfvars (auto-loaded)
environment   = "dev"
instance_type = "t3.micro"
instance_count = 1
```

For other environments, you create separate files:

```hcl
# staging.tfvars
environment   = "staging"
instance_type = "t3.small"
instance_count = 2
```

```hcl
# prod.tfvars
environment   = "prod"
instance_type = "t3.large"
instance_count = 5
```

Deployment commands:

```bash
# Development (uses terraform.tfvars automatically)
terraform apply

# Staging
terraform apply -var-file="staging.tfvars"

# Production
terraform apply -var-file="prod.tfvars"

# Emergency override (command line wins)
terraform apply -var-file="prod.tfvars" -var="instance_count=10"
```

### Best Practice Directory Structure

```
project/
  main.tf
  variables.tf
  outputs.tf
  locals.tf
  terraform.tfvars      # Common defaults (auto-loaded)
  dev.tfvars            # Development overrides
  staging.tfvars        # Staging overrides
  prod.tfvars           # Production overrides
```

---

## Section 4: Outputs and Locals

### Outputs

Outputs expose values from your infrastructure. They serve three critical purposes in real-world Terraform usage.

First, outputs display information after terraform apply. When you create an EC2 instance, you want to see its IP address immediately.

Second, outputs share data between modules. When one module creates a VPC and another creates EC2 instances in that VPC, outputs pass the VPC ID between them.

Third, outputs enable querying with terraform output command. Scripts and CI/CD pipelines can extract values programmatically.

```hcl
output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Public IP address of the instance"
  value       = aws_instance.web.public_ip
}

output "connection_string" {
  description = "SSH connection command"
  value       = "ssh -i key.pem ec2-user@${aws_instance.web.public_ip}"
}

# Sensitive output - hidden in console
output "database_password" {
  description = "Database admin password"
  value       = random_password.db.result
  sensitive   = true
}

# Conditional output
output "load_balancer_dns" {
  description = "Load balancer DNS name"
  value       = var.create_lb ? aws_lb.main[0].dns_name : null
}
```

### Locals

Locals are named expressions that simplify complex configurations. They serve two purposes.

First, locals avoid repetition. If you use the same expression in five places, define it once as a local. When you need to change it, you change one line instead of five.

Second, locals give meaningful names to computed values. Reading local.is_production is clearer than reading var.environment == "prod" scattered throughout your code.

```hcl
locals {
  # Common tags applied to all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
    CostCenter  = var.environment == "prod" ? "production" : "development"
  }
  
  # Computed name prefix used everywhere
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Boolean flags for conditional logic
  is_production = var.environment == "prod"
  
  # Environment-specific sizing
  instance_type = local.is_production ? "t3.large" : "t3.micro"
  instance_count = local.is_production ? 3 : 1
}

# Using locals in resources
resource "aws_instance" "web" {
  count         = local.instance_count
  instance_type = local.instance_type
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-${count.index + 1}"
  })
}
```

---

## Section 5: Functions and Expressions

### Why Functions Matter

Raw data rarely matches what your infrastructure needs. You receive a VPC CIDR block and need to calculate subnet ranges. You have a list of environments and need to check if production is included. You need to merge default tags with resource-specific tags.

Functions transform data. They are the tools that convert what you have into what you need. Mastering functions separates basic Terraform configurations from production-ready code.

### String Functions

String functions manipulate text values.

```hcl
locals {
  # Convert to lowercase for S3 bucket names
  bucket_name = lower("My-Application-Bucket")
  # Result: "my-application-bucket"
  
  # Convert to uppercase for environment tags
  env_tag = upper(var.environment)
  # Result: "PROD"
  
  # Format with placeholders
  server_name = format("server-%s-%03d", var.environment, 5)
  # Result: "server-prod-005"
  
  # Join list into comma-separated string
  zone_list = join(", ", var.availability_zones)
  # Result: "us-east-1a, us-east-1b, us-east-1c"
  
  # Split string into list
  parts = split("-", "web-server-prod")
  # Result: ["web", "server", "prod"]
  
  # Replace characters
  safe_name = replace("my_bucket_name", "_", "-")
  # Result: "my-bucket-name"
  
  # Trim whitespace
  clean = trimspace("  hello world  ")
  # Result: "hello world"
}
```

### Collection Functions

Collection functions work with lists, maps, and sets.

```hcl
locals {
  # Length of list or map
  zone_count = length(var.availability_zones)
  # Result: 3
  
  # Merge multiple maps
  all_tags = merge(
    local.common_tags,
    { Name = "web-server" },
    var.extra_tags
  )
  
  # Lookup with default fallback
  instance_type = lookup(var.instance_types, var.environment, "t3.micro")
  # If environment not found, returns "t3.micro"
  
  # Concatenate lists
  all_subnets = concat(var.public_subnets, var.private_subnets)
  
  # Flatten nested lists
  all_cidrs = flatten([var.vpc_cidrs, var.additional_cidrs])
  
  # Get unique values
  unique_zones = distinct(var.zones)
  
  # Check if value exists
  has_production = contains(var.environments, "prod")
  # Result: true or false
  
  # Get element by index
  first_zone = element(var.availability_zones, 0)
  
  # Get keys from map
  env_names = keys(var.instance_types)
  # Result: ["dev", "staging", "prod"]
  
  # Get values from map
  sizes = values(var.instance_types)
  # Result: ["t3.micro", "t3.small", "t3.large"]
}
```

### Numeric Functions

```hcl
locals {
  # Minimum and maximum
  min_count = min(var.desired_count, var.max_count)
  max_size = max(var.disk_sizes)
  
  # Ceiling and floor
  instances_needed = ceil(var.total_capacity / var.instance_capacity)
  
  # Absolute value
  difference = abs(var.current - var.target)
}
```

### Network Functions

Network functions are essential for VPC and subnet calculations.

```hcl
locals {
  vpc_cidr = "10.0.0.0/16"
  
  # Calculate subnet CIDRs
  # cidrsubnet(base, newbits, netnum)
  # newbits: additional bits to add (16 + 8 = 24)
  # netnum: which subnet (0, 1, 2, ...)
  
  public_subnet_1 = cidrsubnet(local.vpc_cidr, 8, 0)
  # Result: "10.0.0.0/24"
  
  public_subnet_2 = cidrsubnet(local.vpc_cidr, 8, 1)
  # Result: "10.0.1.0/24"
  
  private_subnet_1 = cidrsubnet(local.vpc_cidr, 8, 10)
  # Result: "10.0.10.0/24"
  
  private_subnet_2 = cidrsubnet(local.vpc_cidr, 8, 11)
  # Result: "10.0.11.0/24"
  
  # Calculate host addresses
  first_host = cidrhost(local.public_subnet_1, 1)
  # Result: "10.0.0.1"
}
```

### Encoding Functions

```hcl
locals {
  # Encode to JSON for IAM policies
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "${aws_s3_bucket.main.arn}/*"
    }]
  })
  
  # Decode JSON from file
  config = jsondecode(file("config.json"))
  
  # Base64 encoding for user data
  user_data_encoded = base64encode(file("scripts/init.sh"))
}
```

### Filesystem Functions

```hcl
resource "aws_instance" "web" {
  # Read file content
  user_data = file("${path.module}/scripts/bootstrap.sh")
}

resource "aws_lambda_function" "handler" {
  # Read and hash file for change detection
  source_code_hash = filebase64sha256("lambda.zip")
  filename         = "lambda.zip"
}

locals {
  # Check if file exists
  config_exists = fileexists("config.json")
  
  # Get directory of current module
  module_path = path.module
}
```

---

## Section 6: Conditional Expressions and Loops

### Conditional Expressions

The ternary operator creates different configurations based on conditions. It follows the pattern: condition ? true_value : false_value.

```hcl
resource "aws_instance" "web" {
  # Different instance types per environment
  instance_type = var.environment == "prod" ? "t3.large" : "t3.micro"
  
  # Enable monitoring only in production
  monitoring = var.environment == "prod" ? true : false
  
  # Conditional count - create or skip resource
  count = var.create_instance ? 1 : 0
}

locals {
  # Complex conditional
  instance_type = (
    var.environment == "prod" ? "t3.large" :
    var.environment == "staging" ? "t3.medium" :
    "t3.micro"
  )
}
```

### Count Meta-Argument

Count creates multiple copies of a resource. Each copy is identified by its index.

```hcl
variable "instance_count" {
  type    = number
  default = 3
}

resource "aws_instance" "web" {
  count         = var.instance_count
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  
  tags = {
    Name = "web-server-${count.index + 1}"
  }
}

# Access individual instances
output "first_instance_id" {
  value = aws_instance.web[0].id
}

# Access all instance IDs using splat expression
output "all_instance_ids" {
  value = aws_instance.web[*].id
}

# Conditional resource creation
resource "aws_eip" "web" {
  count    = var.create_eip ? var.instance_count : 0
  instance = aws_instance.web[count.index].id
}
```

### For Each Meta-Argument

For_each iterates over maps or sets. Unlike count, it uses keys instead of numeric indices. This makes your infrastructure more stable when items are added or removed.

```hcl
variable "instances" {
  type = map(object({
    instance_type = string
    ami           = string
  }))
  default = {
    web = {
      instance_type = "t3.micro"
      ami           = "ami-0c101f26f147fa7fd"
    }
    api = {
      instance_type = "t3.small"
      ami           = "ami-0c101f26f147fa7fd"
    }
    worker = {
      instance_type = "t3.medium"
      ami           = "ami-0c101f26f147fa7fd"
    }
  }
}

resource "aws_instance" "servers" {
  for_each      = var.instances
  ami           = each.value.ami
  instance_type = each.value.instance_type
  
  tags = {
    Name = each.key
    Role = each.key
  }
}

# Access by key
output "web_instance_id" {
  value = aws_instance.servers["web"].id
}

# Get all instance IDs as a map
output "all_instance_ids" {
  value = { for k, v in aws_instance.servers : k => v.id }
}
```

### For Expressions

For expressions transform collections. They create new lists or maps from existing ones.

```hcl
locals {
  # Transform list - uppercase all names
  upper_names = [for name in var.names : upper(name)]
  
  # Filter list - only production servers
  production_servers = [
    for server in var.servers : server
    if server.environment == "prod"
  ]
  
  # Transform list to map
  instance_map = {
    for idx, id in aws_instance.web[*].id :
    "server-${idx}" => id
  }
  
  # Transform map values
  instance_arns = {
    for k, v in aws_instance.servers :
    k => v.arn
  }
  
  # Flatten nested structure
  all_subnets = flatten([
    for vpc_key, vpc in var.vpcs : [
      for subnet in vpc.subnets : {
        vpc_key    = vpc_key
        subnet_cidr = subnet
      }
    ]
  ])
}
```

### Dynamic Blocks

Dynamic blocks generate repeated nested blocks from a collection. They are essential for security groups, IAM policies, and other resources with repeating configuration blocks.

```hcl
variable "ingress_rules" {
  type = list(object({
    description = string
    port        = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      description = "HTTP from anywhere"
      port        = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTPS from anywhere"
      port        = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "SSH from VPC"
      port        = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    }
  ]
}

resource "aws_security_group" "web" {
  name        = "web-server-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id
  
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

---

## Section 7: String Interpolation

### Basic Interpolation

String interpolation embeds expressions inside strings using the ${...} syntax.

```hcl
locals {
  environment = "prod"
  project     = "webapp"
  
  # Basic interpolation
  bucket_name = "my-bucket-${local.environment}"
  # Result: "my-bucket-prod"
  
  # Multiple interpolations
  resource_name = "${local.project}-${local.environment}-server"
  # Result: "webapp-prod-server"
  
  # With function results
  unique_name = "bucket-${random_id.suffix.hex}"
  
  # With resource attributes
  connection = "postgres://${aws_db_instance.main.address}:5432/mydb"
}
```

### Heredoc Syntax

For multi-line strings, use heredoc syntax. The <<- variant strips leading indentation.

```hcl
resource "aws_instance" "web" {
  user_data = <<-EOF
    #!/bin/bash
    echo "Environment: ${var.environment}"
    echo "Server: ${var.server_name}"
    
    yum update -y
    yum install -y httpd
    
    systemctl start httpd
    systemctl enable httpd
  EOF
}
```

### Template Files

For complex templates, use the templatefile function. This keeps your Terraform code clean and templates maintainable.

```hcl
resource "aws_instance" "web" {
  user_data = templatefile("${path.module}/scripts/init.sh.tpl", {
    environment = var.environment
    db_host     = aws_db_instance.main.address
    db_port     = 5432
    app_port    = var.app_port
    region      = var.aws_region
  })
}
```

---

# Part 2: Practice

## Lab Overview

This section contains two comprehensive labs that cover all concepts from the theory.

| Lab | Topic | Duration |
|-----|-------|----------|
| Lab 1 | Parameterized VPC Infrastructure | 45 min |
| Lab 2 | Multi-Environment with Dynamic Security Groups | 45 min |

---

## Lab 1: Parameterized VPC Infrastructure

### Directory

lab-parameterized-vpc/

### Objective

Build a complete VPC with subnets and EC2 instances using parameterized configuration. This lab demonstrates variables, validation, locals, count, and conditional resources.

### Key Concepts Demonstrated

- Input variables with types and validation rules
- Variable precedence (defaults, tfvars, env vars, CLI)
- Using locals for computed values and common tags
- The count meta-argument for multiple subnets and instances
- Conditional resource creation (NAT Gateway)
- The cidrsubnet function for subnet calculations

### Resources Created

- VPC with DNS support enabled
- Public Subnets (configurable count)
- Private Subnets (configurable count)
- Internet Gateway
- NAT Gateway (conditional based on variable)
- Route Tables with associations
- Security Group for web servers
- EC2 Instances (configurable count)

### Commands

```bash
cd lab-parameterized-vpc
terraform init
terraform plan
terraform apply

# Test variable precedence
export TF_VAR_environment="staging"
terraform plan

terraform plan -var-file="prod.tfvars"
terraform plan -var="instance_count=5"

# Cleanup
terraform destroy
```

---

## Lab 2: Multi-Environment with Dynamic Security Groups

### Directories

- lab-dynamic-security-groups/
- lab-multi-environment/

### Objective

Build infrastructure that adapts to different environments using dynamic blocks, for_each, and environment-specific configurations.

### Key Concepts Demonstrated

- Dynamic blocks for security group rules
- for_each with maps for multiple resources
- Complex variable types (list of objects, map of objects)
- Environment-specific configurations using map lookups
- Conditional resources based on environment
- Production vs development feature flags

### Commands

```bash
# Dynamic Security Groups lab
cd lab-dynamic-security-groups
terraform init
terraform apply

# Multi-Environment lab
cd lab-multi-environment
terraform init

# Deploy different environments
terraform apply -var-file="dev.tfvars"
terraform destroy -var-file="dev.tfvars"

terraform apply -var-file="prod.tfvars"
terraform output configuration_summary

terraform destroy -var-file="prod.tfvars"
```

---

# Summary

## Key Concepts

| Concept | Purpose | Example |
|---------|---------|---------|
| Variables | Make configurations reusable | var.environment |
| Validation | Catch errors early | contains(["dev", "prod"], var.env) |
| Precedence | Control which values win | -var overrides tfvars |
| Locals | Simplify expressions | local.name_prefix |
| Functions | Transform data | cidrsubnet, merge, lookup |
| count | Create multiple copies | count = var.instance_count |
| for_each | Iterate with keys | for_each = var.instances |
| dynamic | Generate nested blocks | dynamic "ingress" { } |

## Next Steps

After completing this lecture, students should practice with real AWS accounts and explore the following topics in future lectures:

- Terraform modules for code reuse
- State management and remote backends
- Workspace management for environment isolation
- Provider configurations and aliases
