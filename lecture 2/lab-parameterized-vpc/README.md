# Lab 1: Parameterized VPC Infrastructure

## Objective

Build a complete VPC with subnets and EC2 instances using parameterized configuration. This lab demonstrates variables, validation, locals, count, and conditional resources.

## What You Will Learn

- Input variables with types and validation rules
- Variable precedence and different ways to set values
- Using locals for computed values
- The count meta-argument for multiple resources
- Conditional resource creation
- The cidrsubnet function for subnet calculations

## Resources Created

- 1 VPC
- 2-3 Public Subnets
- 2-3 Private Subnets
- 1 Internet Gateway
- 1 NAT Gateway (optional)
- Route Tables and Associations
- 1 Security Group
- 1-5 EC2 Instances

## Files in This Lab

| File | Purpose |
|------|---------|
| variables.tf | Input variables with validation rules |
| locals.tf | Computed values and common tags |
| main.tf | VPC, subnets, EC2, and all resources |
| outputs.tf | Output values |
| terraform.tfvars | Default variable values |
| prod.tfvars | Production overrides |

---

## Part 1: Understanding Variable Precedence

### Step 1: Review Variable Sources

Variables can be set from multiple sources. The precedence order (lowest to highest):

1. Default values in variables.tf
2. Environment variables (TF_VAR_name)
3. terraform.tfvars (auto-loaded)
4. *.auto.tfvars files
5. -var-file flag
6. -var flag (highest priority)

### Step 2: Test Precedence

```bash
# Initialize Terraform
terraform init

# 1. Use default values from terraform.tfvars
terraform plan
# Shows: environment = "dev", instance_count = 2

# 2. Override with environment variable
export TF_VAR_environment="staging"
terraform plan
# Shows: environment = "staging"

# 3. Override with -var-file
terraform plan -var-file="prod.tfvars"
# Shows: environment = "prod", instance_count = 3

# 4. Override with -var (highest priority)
terraform plan -var-file="prod.tfvars" -var="instance_count=1"
# Shows: environment = "prod", instance_count = 1

# Clean up environment variable
unset TF_VAR_environment
```

---

## Part 2: Validation Rules

### Step 3: Test Validation

```bash
# Test invalid environment
terraform plan -var="environment=invalid"
# Error: Environment must be dev, staging, or prod.

# Test invalid instance count
terraform plan -var="instance_count=10"
# Error: Instance count must be between 1 and 5.

# Test invalid email
terraform plan -var="owner=notanemail"
# Error: Owner must be a valid email address.

# Test invalid CIDR
terraform plan -var="vpc_cidr=invalid"
# Error: VPC CIDR must be a valid IPv4 CIDR block.
```

---

## Part 3: Deploy Infrastructure

### Step 4: Deploy Development Environment

```bash
terraform plan
terraform apply
```

### Step 5: View Outputs

```bash
terraform output
terraform output vpc_id
terraform output public_subnet_cidrs
terraform output instance_public_ips
```

### Step 6: Understand cidrsubnet

The cidrsubnet function calculates subnet CIDRs:

```hcl
cidrsubnet("10.0.0.0/16", 8, 0)  = "10.0.0.0/24"   # Public 1
cidrsubnet("10.0.0.0/16", 8, 1)  = "10.0.1.0/24"   # Public 2
cidrsubnet("10.0.0.0/16", 8, 10) = "10.0.10.0/24"  # Private 1
cidrsubnet("10.0.0.0/16", 8, 11) = "10.0.11.0/24"  # Private 2
```

---

## Part 4: Modify Configuration

### Step 7: Add More Subnets

```bash
terraform apply -var="public_subnet_count=3" -var="private_subnet_count=3"
```

### Step 8: Enable NAT Gateway

```bash
terraform apply -var="enable_nat_gateway=true"
```

### Step 9: Deploy Production Configuration

```bash
terraform destroy
terraform apply -var-file="prod.tfvars"
```

---

## Exercises

### Exercise 1: Add a New Validation

Add a validation rule to vpc_cidr that ensures it is a /16 network.

### Exercise 2: Create staging.tfvars

Create a staging.tfvars file with values between dev and prod.

### Exercise 3: Add Environment Variable

Test using TF_VAR_instance_type to override the instance type.

---

## Cleanup

```bash
terraform destroy
```
