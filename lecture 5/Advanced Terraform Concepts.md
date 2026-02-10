# Lecture 5: Advanced Terraform Concepts

This lecture covers production-grade Terraform practices including workspaces, import workflows, lifecycle management, and CI/CD automation. By the end of this session, students will have the skills to manage Terraform at scale in real-world environments.

---

# Part 1: Theory

## Section 1: Terraform Workspaces

### Why Workspaces Matter

You manage infrastructure for three environments: development, staging, and production. Each environment has the same resources but different configurations. How do you organize this?

Option 1: Three separate directories with duplicated code. When you fix a bug, you update it three times. When configurations drift, you spend hours reconciling differences.

Option 2: One codebase with three state files managed through workspaces. Change once, apply to each environment. Consistent patterns. Minimal duplication.

Workspaces solve the multi-environment problem by allowing multiple state files within a single configuration. Each workspace has its own state, but shares the same Terraform code.

### What are Workspaces

Workspaces are named state file containers. By default, Terraform uses the "default" workspace. You can create additional workspaces for different environments.

```bash
# List workspaces
terraform workspace list

# Create new workspace
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Switch workspace
terraform workspace select dev

# Show current workspace
terraform workspace show
```

### How Workspaces Work

When you create a workspace, Terraform creates a separate state file:

```
terraform.tfstate.d/
  dev/
    terraform.tfstate
  staging/
    terraform.tfstate
  prod/
    terraform.tfstate
```

Each workspace maintains independent state. Resources in the dev workspace do not affect staging or prod.

### Using Workspace Name in Configuration

Access the current workspace name with `terraform.workspace`:

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  tags = {
    Name        = "${terraform.workspace}-web-server"
    Environment = terraform.workspace
  }
}
```

### Environment-Specific Variables

Use workspace name to select configurations:

```hcl
locals {
  environment_config = {
    dev = {
      instance_type = "t3.micro"
      instance_count = 1
    }
    staging = {
      instance_type = "t3.small"
      instance_count = 2
    }
    prod = {
      instance_type = "t3.medium"
      instance_count = 3
    }
  }
  
  config = local.environment_config[terraform.workspace]
}

resource "aws_instance" "web" {
  count         = local.config.instance_count
  instance_type = local.config.instance_type
  
  tags = {
    Name = "${terraform.workspace}-web-${count.index + 1}"
  }
}
```

### Workspace Best Practices

1. Use workspaces for environments with identical infrastructure patterns
2. Do not use workspaces for completely different projects
3. Always check current workspace before applying: `terraform workspace show`
4. Use workspace-specific variable files: `terraform apply -var-file="${terraform.workspace}.tfvars"`
5. Consider workspace limitations with remote backends

### Workspace Limitations

Workspaces are not suitable for:
- Completely different infrastructure architectures
- Different AWS accounts (use separate backends instead)
- Long-term environment isolation (consider separate state backends)

---

## Section 2: Backend Configuration Patterns

### The Backend Configuration Challenge

You cannot use variables in backend configuration:

```hcl
# This does NOT work
terraform {
  backend "s3" {
    bucket = var.bucket_name  # ERROR!
  }
}
```

Backend configuration must use literal values. This creates a problem: how do you manage multiple environments with different backends?

### Pattern 1: Partial Configuration

Define the backend type without values:

```hcl
# backend.tf
terraform {
  backend "s3" {}
}
```

Provide values during initialization:

```bash
terraform init \
  -backend-config="bucket=my-terraform-state" \
  -backend-config="key=prod/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=terraform-locks"
```

### Pattern 2: Backend Configuration Files

Create environment-specific backend files:

```hcl
# backend-dev.hcl
bucket         = "terraform-state-dev"
key            = "infrastructure/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-locks-dev"
```

```hcl
# backend-prod.hcl
bucket         = "terraform-state-prod"
key            = "infrastructure/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-locks-prod"
```

Initialize with the appropriate file:

```bash
terraform init -backend-config=backend-dev.hcl
terraform init -backend-config=backend-prod.hcl
```

### Pattern 3: Environment Directories

Separate directories per environment:

```
infrastructure/
  modules/
    vpc/
    ec2/
  environments/
    dev/
      main.tf
      backend.tf
      terraform.tfvars
    staging/
      main.tf
      backend.tf
      terraform.tfvars
    prod/
      main.tf
      backend.tf
      terraform.tfvars
```

Each environment has its own backend configuration.

---

## Section 3: Terraform Import

### Why Import Matters

Your company has been running AWS infrastructure for years. Hundreds of resources exist, all created manually through the console. Now you want to manage them with Terraform.

Do you destroy everything and recreate it? Unacceptable downtime. Do you maintain two systems forever? Operational nightmare.

Terraform import solves this. It brings existing infrastructure under Terraform management without recreating it.

### How Import Works

Import maps existing resources to Terraform configuration:

1. Write the resource configuration in Terraform
2. Run terraform import with the resource address and ID
3. Terraform adds the resource to state
4. Future applies manage the imported resource

### Import Syntax

```bash
terraform import <resource_address> <resource_id>
```

Example:

```bash
# Import an EC2 instance
terraform import aws_instance.web i-0abc123def456789

# Import a VPC
terraform import aws_vpc.main vpc-0abc123

# Import a security group
terraform import aws_security_group.web sg-0abc123
```

### Import Workflow

Step 1: Write the configuration

```hcl
resource "aws_instance" "web" {
  # Configuration will be filled after import
}
```

Step 2: Import the resource

```bash
terraform import aws_instance.web i-0abc123def456789
```

Step 3: View the imported state

```bash
terraform state show aws_instance.web
```

Step 4: Update configuration to match

Copy attributes from state to your configuration:

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c101f26f147fa7fd"
  instance_type = "t3.micro"
  subnet_id     = "subnet-abc123"
  
  tags = {
    Name = "imported-web-server"
  }
}
```

Step 5: Verify with plan

```bash
terraform plan
```

Should show no changes if configuration matches reality.

### Import Limitations

1. Import does not generate configuration - you must write it
2. Import only works for resources, not data sources
3. Some resources cannot be imported
4. Import does not import resource dependencies

### Import for Modules

Import into a module:

```bash
terraform import module.vpc.aws_vpc.main vpc-0abc123
```

---

## Section 4: Terraform Taint and Replace

### The Taint Problem

An EC2 instance is running but corrupted. The application crashed and left the system in a bad state. You need to recreate it, but Terraform thinks everything is fine because the resource exists.

Historically, you would taint the resource to force recreation. Modern Terraform uses the replace command instead.

### Legacy: Terraform Taint (Deprecated)

```bash
# Old way (deprecated in Terraform 0.15.2+)
terraform taint aws_instance.web
terraform apply
```

This marked the resource for recreation on the next apply.

### Modern: Terraform Replace

```bash
# New way
terraform apply -replace="aws_instance.web"
```

This recreates the resource in a single command.

### When to Use Replace

1. Resource is in a bad state
2. Configuration changes require recreation
3. Testing disaster recovery procedures
4. Forcing updates that Terraform does not detect

### Replace with Plan

Preview the replacement:

```bash
terraform plan -replace="aws_instance.web"
```

### Replace Multiple Resources

```bash
terraform apply \
  -replace="aws_instance.web" \
  -replace="aws_instance.app"
```

---

## Section 5: Lifecycle Rules

### Why Lifecycle Rules Matter

You update a database configuration. Terraform destroys the old database before creating the new one. Your application crashes. Data is lost. Customers are angry.

This is the default Terraform behavior: destroy then create. For critical resources, this is unacceptable.

Lifecycle rules give you control over resource creation and destruction order. They prevent data loss and minimize downtime.

### create_before_destroy

Create the new resource before destroying the old one:

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  lifecycle {
    create_before_destroy = true
  }
}
```

Terraform creates the new instance, updates dependencies, then destroys the old instance. Zero downtime.

### prevent_destroy

Prevent accidental deletion of critical resources:

```hcl
resource "aws_s3_bucket" "data" {
  bucket = "critical-data-bucket"
  
  lifecycle {
    prevent_destroy = true
  }
}
```

If you try to destroy this resource:

```bash
terraform destroy
```

Terraform errors:

```
Error: Instance cannot be destroyed

Resource aws_s3_bucket.data has lifecycle.prevent_destroy set,
but the plan calls for this resource to be destroyed.
```

You must remove the lifecycle block to destroy the resource.

### ignore_changes

Ignore changes to specific attributes:

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  tags = {
    Name = "web-server"
  }
  
  lifecycle {
    ignore_changes = [
      tags,  # Ignore all tag changes
    ]
  }
}
```

Useful when:
- External systems modify resources
- Auto-scaling changes instance counts
- Tags are managed outside Terraform

### ignore_changes for Specific Attributes

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  tags = {
    Name        = "web-server"
    Environment = "production"
  }
  
  lifecycle {
    ignore_changes = [
      tags["Environment"],  # Ignore only Environment tag
    ]
  }
}
```

### Combining Lifecycle Rules

```hcl
resource "aws_db_instance" "main" {
  identifier     = "production-db"
  engine         = "postgres"
  instance_class = "db.t3.medium"
  
  lifecycle {
    create_before_destroy = true
    prevent_destroy       = true
    ignore_changes        = [
      password,  # Password managed externally
    ]
  }
}
```

---

## Section 6: Sensitive Variables

### The Sensitive Data Problem

You run terraform plan and see:

```
+ password = "SuperSecretPassword123!"
```

The password is visible in logs, CI/CD output, and terminal history. Anyone with access sees your secrets.

Sensitive variables solve this by hiding values in output.

### Marking Variables as Sensitive

```hcl
variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}
```

Now when you run terraform plan:

```
+ password = (sensitive value)
```

The actual value is hidden.

### Sensitive Outputs

```hcl
output "db_password" {
  description = "Database password"
  value       = var.db_password
  sensitive   = true
}
```

Output is hidden unless explicitly requested:

```bash
terraform output db_password
```

### Sensitive in Locals

```hcl
locals {
  db_connection_string = "postgresql://user:${var.db_password}@${aws_db_instance.main.endpoint}/mydb"
}

output "connection_string" {
  value     = local.db_connection_string
  sensitive = true
}
```

### Best Practices for Secrets

1. Always mark passwords and keys as sensitive
2. Use secret management systems (AWS Secrets Manager, Vault)
3. Never commit secrets to version control
4. Use environment variables for sensitive inputs
5. Rotate secrets regularly

---

## Section 7: Terraform Formatting and Validation

### terraform fmt

Automatically format Terraform files to canonical style:

```bash
# Format all files in current directory
terraform fmt

# Format recursively
terraform fmt -recursive

# Check if files are formatted (CI/CD)
terraform fmt -check

# Show diff of changes
terraform fmt -diff
```

### Formatting Rules

Terraform fmt applies consistent:
- Indentation (2 spaces)
- Alignment of equals signs
- Argument ordering
- Spacing around operators

Before:

```hcl
resource "aws_instance" "web"{
ami="ami-123"
  instance_type =   "t3.micro"
    tags={
Name="web"
}
}
```

After terraform fmt:

```hcl
resource "aws_instance" "web" {
  ami           = "ami-123"
  instance_type = "t3.micro"
  
  tags = {
    Name = "web"
  }
}
```

### terraform validate

Check configuration for syntax and logical errors:

```bash
terraform validate
```

Validates:
- Syntax correctness
- Resource attribute names
- Required arguments
- Type constraints
- Module configurations

Example errors:

```
Error: Missing required argument

  on main.tf line 5:
   5: resource "aws_instance" "web" {

The argument "ami" is required, but no definition was found.
```

### Validation in CI/CD

```bash
# Format check
terraform fmt -check -recursive

# Validate configuration
terraform init -backend=false
terraform validate

# Exit with error if validation fails
if [ $? -ne 0 ]; then
  echo "Terraform validation failed"
  exit 1
fi
```

---

# Part 2: Practice

## Lab Overview

This section contains two comprehensive labs covering production Terraform practices.

| Lab | Topic | Duration |
|-----|-------|----------|
| Lab 1 | Workspaces & Workspace Variables | 30 min |
| Lab 2 | Import, Lifecycle & CI/CD | 35 min |

---

## Lab 1: Workspaces & Workspace Variables

### Directory

lab-workspaces/

### Objective

Create and manage multiple workspaces, then use workspace-specific configurations with locals to deploy different infrastructure per environment.

### Key Concepts

- Creating and switching workspaces
- Workspace-specific state files
- Using terraform.workspace variable
- Environment-specific variables via locals maps
- Conditional resource sizing per workspace

### Part A: Create Workspaces (15 min)

```bash
cd lab-workspaces
terraform init

# Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Switch and apply
terraform workspace select dev
terraform apply

terraform workspace select prod
terraform apply
```

### Part B: Compare Workspace Variables (15 min)

```bash
# Compare outputs across environments
terraform workspace select dev && terraform output
terraform workspace select staging && terraform output
terraform workspace select prod && terraform output
```

---

## Lab 2: Import, Lifecycle & CI/CD

### Directory

lab-import-lifecycle-cicd/

### Objective

Import a manually-created EC2 instance into Terraform, use lifecycle rules to control resource behavior, and review a GitHub Actions CI/CD pipeline.

### Key Concepts

- terraform import command and workflow
- create_before_destroy for zero downtime
- prevent_destroy for critical resources
- ignore_changes for external modifications
- Automated CI/CD pipeline with GitHub Actions

### Part A: Import Existing EC2 (10 min)

```bash
cd lab-import-lifecycle-cicd
terraform init
terraform import aws_instance.imported i-YOUR-INSTANCE-ID
terraform state show aws_instance.imported
terraform plan
```

### Part B: Lifecycle Rules (15 min)

```bash
terraform apply

# Test create_before_destroy - change user_data then apply
# Test prevent_destroy - try terraform destroy
# Test ignore_changes - change tag in console, then plan
```

### Part C: CI/CD Pipeline (10 min)

Review `.github/workflows/terraform.yml` and understand the three pipeline stages: Format & Validate, Plan on PR, Apply on merge.

---

# Summary

## Key Concepts

| Concept | Purpose | Command/Syntax |
|---------|---------|----------------|
| Workspaces | Multi-environment state | terraform workspace new dev |
| Import | Bring existing resources | terraform import aws_instance.web i-123 |
| Replace | Force recreation | terraform apply -replace="resource" |
| create_before_destroy | Zero downtime updates | lifecycle { create_before_destroy = true } |
| prevent_destroy | Protect critical resources | lifecycle { prevent_destroy = true } |
| Sensitive | Hide secrets | variable "password" { sensitive = true } |
| Format | Consistent style | terraform fmt |
| Validate | Check correctness | terraform validate |

## Production Checklist

- [ ] Use workspaces or separate backends for environments
- [ ] Import existing infrastructure before managing
- [ ] Apply lifecycle rules to critical resources
- [ ] Mark all secrets as sensitive
- [ ] Run terraform fmt before committing
- [ ] Run terraform validate in CI/CD
- [ ] Automate terraform plan on pull requests
- [ ] Require manual approval for terraform apply
- [ ] Use remote state with locking
- [ ] Version control all Terraform code

## Next Steps

After completing this lecture, students should:

- Implement workspace-based workflows
- Import legacy infrastructure
- Build CI/CD pipelines for Terraform
- Apply production best practices
- Explore Terraform Cloud for team collaboration
