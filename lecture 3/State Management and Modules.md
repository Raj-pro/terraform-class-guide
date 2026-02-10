# Lecture 3: Terraform State Management and Modules

This lecture covers how Terraform tracks infrastructure through state files and how to structure reusable infrastructure code using modules. By the end of this session, students will understand state management best practices and how to build modular, maintainable Terraform projects.

---

# Part 1: Theory

## Section 1: Terraform State

### Why State Matters

Imagine deploying infrastructure without any record of what you created. You run terraform apply and EC2 instances appear. A week later, you need to update them. How does Terraform know which instances belong to your configuration? How does it know what changed?

This is the problem Terraform state solves. State is Terraform's memory. It maps your configuration files to real-world resources. Without state, Terraform cannot function.

Every time you run terraform apply, Terraform compares your desired configuration against the current state. It calculates the difference and determines what actions to take. Create new resources. Update existing ones. Destroy removed ones. State makes this possible.

Understanding state is not optional for production Terraform. Losing state means losing control of your infrastructure. Corrupting state means potential outages. Managing state correctly is fundamental to reliable infrastructure as code.

### What is terraform.tfstate

The terraform.tfstate file is a JSON document that records every resource Terraform manages. It contains resource IDs, attributes, dependencies, and metadata.

```json
{
  "version": 4,
  "terraform_version": "1.6.0",
  "serial": 5,
  "lineage": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "outputs": {},
  "resources": [
    {
      "mode": "managed",
      "type": "aws_instance",
      "name": "web",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [
        {
          "schema_version": 1,
          "attributes": {
            "id": "i-0abc123def456789",
            "ami": "ami-0c101f26f147fa7fd",
            "instance_type": "t3.micro",
            "public_ip": "54.123.45.67",
            "private_ip": "10.0.1.25"
          }
        }
      ]
    }
  ]
}
```

Key components:

- version: State file format version
- terraform_version: Terraform version that wrote this state
- serial: Increments with each state change (prevents conflicts)
- lineage: Unique ID for this state file (prevents mixing states)
- resources: Array of all managed resources with their attributes

### How State Works

When you run terraform plan:

1. Terraform reads your configuration files
2. Terraform reads the current state file
3. Terraform queries the actual infrastructure (refresh)
4. Terraform compares desired state vs current state
5. Terraform shows you the planned changes

When you run terraform apply:

1. All the plan steps occur
2. Terraform executes the changes
3. Terraform updates the state file with new resource information
4. Terraform writes the updated state

### State File Location

By default, Terraform stores state locally in terraform.tfstate:

```bash
my-project/
  main.tf
  variables.tf
  terraform.tfstate          # Current state
  terraform.tfstate.backup   # Previous state (safety backup)
```

The backup file preserves the previous state. If something goes wrong during apply, you can recover from the backup.

### Why State is Critical

State serves multiple critical functions:

### Mapping Configuration to Reality

Your configuration says:

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c101f26f147fa7fd"
  instance_type = "t3.micro"
}
```

State records that this maps to instance i-0abc123def456789. Without state, Terraform would create a new instance every time you run apply.

### Performance Optimization

For large infrastructures with hundreds of resources, querying every resource on every plan would be slow. State caches resource attributes, making plans fast.

### Dependency Tracking

State records dependencies between resources. Terraform knows to destroy the instance before destroying the subnet, even if you delete both from your configuration.

### Metadata Storage

State stores information not in your configuration:

- Resource creation timestamps
- Provider-specific metadata
- Computed attributes from the cloud provider

---

## Section 2: State Management Challenges

### The Collaboration Problem

You and your teammate both work on the same infrastructure. You run terraform apply and create an EC2 instance. Your teammate runs terraform apply from their laptop with an old state file. Terraform thinks the instance does not exist and creates a duplicate.

This is the fundamental problem with local state files. They do not synchronize across team members. Each person has their own copy. Changes conflict. Resources duplicate. Infrastructure drifts.

### The Sensitive Data Problem

State files contain everything about your infrastructure. Database passwords. API keys. Private IP addresses. Security group rules. All in plain text JSON.

If you commit terraform.tfstate to Git, you expose all secrets to anyone with repository access. If you store it on a shared drive, you risk unauthorized access. State files are security-sensitive documents.

### The Concurrent Modification Problem

Two people run terraform apply simultaneously. Both read the same state. Both make changes. Both write state. The second write overwrites the first. Changes are lost. Infrastructure becomes inconsistent.

Without locking, concurrent operations corrupt state and create unpredictable infrastructure.

---

## Section 3: Remote State

### Why Remote State

Remote state solves the collaboration, security, and concurrency problems:

1. Centralized storage - Everyone reads and writes the same state
2. Encryption at rest - State is encrypted in storage
3. Encryption in transit - State transfers are encrypted
4. Access control - Only authorized users can access state
5. Versioning - Previous state versions are preserved
6. Locking - Prevents concurrent modifications

### Remote State Backends

Terraform supports multiple remote backends:

- S3 (AWS) with DynamoDB for locking
- Azure Blob Storage with lock support
- Google Cloud Storage
- Terraform Cloud
- Consul
- etcd

### S3 Backend Configuration

The most common remote backend uses AWS S3 for storage and DynamoDB for locking.

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

Configuration breakdown:

- bucket: S3 bucket name for state storage
- key: Path within bucket (allows multiple projects)
- region: AWS region for the bucket
- encrypt: Enable server-side encryption
- dynamodb_table: Table for state locking

### Setting Up S3 Backend

Step 1: Create S3 bucket

```hcl
resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-terraform-state"
  
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

Step 2: Create DynamoDB table for locking

```hcl
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
}
```

Step 3: Configure backend in your project

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### State Locking

When you run terraform apply with a locking backend:

1. Terraform acquires a lock in DynamoDB
2. Terraform performs the operation
3. Terraform releases the lock

If another user tries to run terraform apply while the lock is held:

```
Error: Error acquiring the state lock

Error message: ConditionalCheckFailedException: The conditional request failed
Lock Info:
  ID:        a1b2c3d4-e5f6-7890-abcd-ef1234567890
  Path:      my-terraform-state/prod/terraform.tfstate
  Operation: OperationTypeApply
  Who:       alice@example.com
  Version:   1.6.0
  Created:   2024-01-15 10:30:00 UTC
```

Terraform prevents the operation and shows who holds the lock.

### State Locking Best Practices

1. Always use a backend that supports locking for team environments
2. Never force-unlock unless you are certain no operation is running
3. If a lock is stuck, verify the operation truly failed before unlocking
4. Use short-lived operations to minimize lock duration

---

## Section 4: Sensitive Data in State

### The Problem

State files contain sensitive information:

```json
{
  "resources": [
    {
      "type": "aws_db_instance",
      "attributes": {
        "password": "SuperSecretPassword123!",
        "endpoint": "mydb.abc123.us-east-1.rds.amazonaws.com:5432"
      }
    }
  ]
}
```

Database passwords, API keys, and private data are stored in plain text within state.

### Mitigation Strategies

### Use Remote State with Encryption

Always enable encryption for remote state:

```hcl
terraform {
  backend "s3" {
    bucket  = "my-terraform-state"
    key     = "prod/terraform.tfstate"
    encrypt = true  # Server-side encryption
  }
}
```

### Restrict State Access

Use IAM policies to limit who can read state:

```hcl
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::my-terraform-state/*",
      "Condition": {
        "StringEquals": {
          "aws:PrincipalOrgID": "o-abc123"
        }
      }
    }
  ]
}
```

### Use Sensitive Variables

Mark sensitive variables to prevent them from appearing in logs:

```hcl
variable "db_password" {
  type      = string
  sensitive = true
}

output "db_password" {
  value     = var.db_password
  sensitive = true
}
```

### External Secret Management

Store secrets in dedicated secret managers:

```hcl
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/db/password"
}

resource "aws_db_instance" "main" {
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
}
```

---

## Section 5: Terraform Modules

### Why Modules Matter

You have built a VPC with subnets, route tables, and security groups. It works perfectly. Now you need the same setup for staging. Do you copy-paste 200 lines of configuration? What happens when you need to fix a bug in both environments?

This is the problem modules solve. Modules are reusable packages of Terraform configuration. Write once, use many times. Update once, fix everywhere.

Modules are to Terraform what functions are to programming. They encapsulate complexity, promote reuse, and enforce standards.

### What is a Module

A module is a directory containing Terraform configuration files. Every Terraform configuration is a module. The directory where you run terraform apply is the root module.

```
my-project/
  main.tf          # Root module
  variables.tf
  outputs.tf
```

A child module is a module called by another module:

```
my-project/
  main.tf          # Root module
  modules/
    vpc/
      main.tf      # VPC child module
      variables.tf
      outputs.tf
    ec2/
      main.tf      # EC2 child module
      variables.tf
      outputs.tf
```

### Module Structure

A well-structured module contains:

```
modules/vpc/
  main.tf          # Resource definitions
  variables.tf     # Input variables
  outputs.tf       # Output values
  README.md        # Documentation
  versions.tf      # Provider version constraints
```

### Creating a Module

Example VPC module:

```hcl
# modules/vpc/variables.tf
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
}

# modules/vpc/main.tf
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

resource "aws_subnet" "public" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = var.azs[count.index]
  
  tags = {
    Name = "${var.environment}-public-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "${var.environment}-igw"
  }
}

# modules/vpc/outputs.tf
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}
```

### Using a Module

Call the module from your root configuration:

```hcl
# main.tf
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr    = "10.0.0.0/16"
  environment = "production"
  azs         = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# Reference module outputs
resource "aws_instance" "web" {
  subnet_id = module.vpc.public_subnet_ids[0]
  # ... other configuration
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
```

### Module Sources

Modules can be loaded from multiple sources:

### Local Path

```hcl
module "vpc" {
  source = "./modules/vpc"
}
```

### Git Repository

```hcl
module "vpc" {
  source = "git::https://github.com/myorg/terraform-modules.git//vpc?ref=v1.0.0"
}
```

### Terraform Registry

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.0"
}
```

### Module Versioning

Always pin module versions in production:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"  # Allow 5.x updates, not 6.0
}
```

Version constraints:

- = 1.0.0: Exactly version 1.0.0
- >= 1.0.0: Version 1.0.0 or higher
- ~> 1.0: Version 1.x (but not 2.0)
- >= 1.0, < 2.0: Between 1.0 and 2.0

---

## Section 6: Module Best Practices

### Input Variables

Make modules configurable through variables:

```hcl
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
```

### Output Values

Expose useful information:

```hcl
output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.main.id
}

output "public_ip" {
  description = "Public IP address"
  value       = aws_instance.main.public_ip
}
```

### Documentation

Always include README.md:

```markdown
# EC2 Module

Creates an EC2 instance with standard configuration.

## Usage

```hcl
module "web_server" {
  source = "./modules/ec2"
  
  instance_type = "t3.micro"
  subnet_id     = "subnet-abc123"
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| instance_type | EC2 instance type | string | t3.micro |
| subnet_id | Subnet ID | string | required |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | EC2 instance ID |
| public_ip | Public IP address |
```

### Composition Over Inheritance

Build complex modules from simpler ones:

```hcl
module "vpc" {
  source = "./modules/vpc"
}

module "web_servers" {
  source = "./modules/ec2-cluster"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids
}

module "database" {
  source = "./modules/rds"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
}
```

---

# Part 2: Practice

## Lab Overview

This section contains two comprehensive labs that cover state management and modules.

| Lab | Topic | Duration |
|-----|-------|----------|
| Lab 1 | State Inspection & Remote Backend | 35 min |
| Lab 2 | Build, Use & Reuse EC2 Module | 40 min |

---

## Lab 1: State Inspection & Remote Backend

### Directory

lab-state-management/

### Objective

Create simple infrastructure, examine the state file to understand its structure, then configure a remote S3 backend with DynamoDB locking for team collaboration.

### Key Concepts

- State file structure and resource tracking
- Attribute storage and state backup files
- S3 bucket creation with versioning and encryption
- DynamoDB locking table
- Backend configuration and state migration

### Part A: Inspect State (15 min)

```bash
cd lab-state-management
terraform init
terraform apply
cat terraform.tfstate | jq
cat terraform.tfstate.backup | jq
```

Examine the JSON structure. Identify the resource IDs, attributes, serial number, and lineage. Compare the current state with the backup file.

### Part B: Configure Remote Backend (20 min)

After inspecting local state, configure a remote backend to solve collaboration and security challenges.

```bash
# Add S3 backend configuration to your project
# Then migrate the local state to the remote backend
terraform init -migrate-state

# Verify state is now remote
terraform state list
```

Confirm the state file has been removed locally and is now stored in S3. Check DynamoDB for the lock table entry.

---

## Lab 2: Build, Use & Reuse EC2 Module

### Directory

lab-ec2-module/

### Objective

Build a reusable EC2 module with variables and outputs, call it from a root configuration, then reuse the same module to deploy both dev and prod environments.

### Key Concepts

- Module structure, input variables, and output values
- Resource encapsulation
- Module source paths and passing variables
- Accessing module outputs
- Environment-specific configurations and DRY principles

### Part A: Create the Module (15 min)

Create the module directory structure with main.tf, variables.tf, and outputs.tf. Define input variables for instance_type, subnet_id, and tags. Create the EC2 resource and expose instance_id and public_ip as outputs.

### Part B: Use the Module (10 min)

Call the module from your root configuration. Pass in the required variables and reference the module outputs.

```bash
cd lab-ec2-module
terraform init
terraform plan
terraform apply
```

Verify the outputs show the instance ID and public IP from the module.

### Part C: Reuse for Dev & Prod (15 min)

Create two module calls with different configurations for dev and prod environments.

```bash
# Apply and observe two separate environments created from the same module
terraform plan
terraform apply

# Verify both environments
terraform output

---

# Summary

## Key Concepts

| Concept | Purpose | Example |
|---------|---------|---------|
| State File | Tracks infrastructure | terraform.tfstate |
| Remote State | Team collaboration | S3 + DynamoDB backend |
| State Locking | Prevent conflicts | DynamoDB lock table |
| Modules | Code reuse | module "vpc" { source = "./modules/vpc" } |
| Module Outputs | Expose values | output "vpc_id" { value = aws_vpc.main.id } |
| Module Versioning | Stability | version = "~> 5.0" |

## Best Practices

1. Always use remote state for team projects
2. Enable state encryption and versioning
3. Restrict state file access with IAM
4. Use modules for reusable infrastructure patterns
5. Version your modules
6. Document module inputs and outputs
7. Never manually edit state files
8. Use terraform state commands for state operations

## Next Steps

After completing this lecture, students should:

- Set up remote state for all projects
- Build a library of reusable modules
- Explore the Terraform Registry for public modules
- Learn about workspaces for environment management
- Study state import and migration strategies
