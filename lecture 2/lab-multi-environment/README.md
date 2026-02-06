# Lab 4: Multi-Environment Challenge

## Objective

Build infrastructure that adapts to different environments using variables, locals, and conditional logic. This challenge brings together all concepts from the lecture.

## What You Will Learn

- Environment-specific configurations using maps
- Conditional resource creation
- Using tfvars files for different environments
- Production vs development sizing

## Files in This Lab

| File | Purpose |
|------|---------|
| variables.tf | Environment maps and base variables |
| locals.tf | Computed environment-specific values |
| main.tf | VPC, subnets, EC2, conditional resources |
| outputs.tf | Configuration summary and cost estimate |
| dev.tfvars | Development configuration |
| staging.tfvars | Staging configuration |
| prod.tfvars | Production configuration |

## Environment Differences

| Feature | Dev | Staging | Prod |
|---------|-----|---------|------|
| Instance Type | t3.micro | t3.small | t3.large |
| Instance Count | 1 | 2 | 4 |
| Volume Size | 20 GB | 50 GB | 200 GB |
| Monitoring | No | Yes | Yes |
| Elastic IPs | No | No | Yes |
| CloudWatch Alarms | No | No | Yes |
| SSH Access | Yes | Yes | No |

## Steps to Execute

### Step 1: Initialize Terraform

```bash
terraform init
```

### Step 2: Deploy Development Environment

```bash
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

### Step 3: View Configuration

```bash
terraform output configuration_summary
terraform output cost_estimate
```

### Step 4: Destroy Development

```bash
terraform destroy -var-file="dev.tfvars"
```

### Step 5: Deploy Staging Environment

```bash
terraform plan -var-file="staging.tfvars"
terraform apply -var-file="staging.tfvars"
```

### Step 6: Destroy Staging

```bash
terraform destroy -var-file="staging.tfvars"
```

### Step 7: Deploy Production Environment

```bash
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"
```

### Step 8: Verify Production Features

```bash
# Should show Elastic IPs
terraform output instance_public_ips

# Should show production configuration
terraform output configuration_summary
```

## Key Concepts Demonstrated

### Map Lookups

```hcl
local.instance_type = lookup(var.instance_types, var.environment, "t3.micro")
```

### Conditional Resources

```hcl
# Elastic IPs only in production
resource "aws_eip" "web" {
  count = local.is_production ? local.instance_count : 0
  ...
}
```

### Dynamic Blocks with Conditions

```hcl
# SSH only in non-production
dynamic "ingress" {
  for_each = local.is_production ? [] : [1]
  content {
    from_port = 22
    ...
  }
}
```

### Conditional Outputs

```hcl
output "instance_public_ips" {
  value = local.is_production ? aws_eip.web[*].public_ip : aws_instance.web[*].public_ip
}
```

## Exercises

### Exercise 1: Compare Environments

Run terraform plan with different var-files to see the differences:

```bash
terraform plan -var-file="dev.tfvars"
terraform plan -var-file="staging.tfvars"
terraform plan -var-file="prod.tfvars"
```

### Exercise 2: Add a New Environment

Create a new uat.tfvars for User Acceptance Testing environment.

### Exercise 3: Add Environment-Specific Tags

Add cost center tags that differ by environment.

## Cleanup

```bash
terraform destroy -var-file="prod.tfvars"
```
