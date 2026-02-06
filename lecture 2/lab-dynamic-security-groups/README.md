# Lab 3: Dynamic Security Group Rules

## Objective

Create security groups with dynamic blocks that generate rules from variable input. This demonstrates how to manage complex, repeatable configurations.

## What You Will Learn

- Using dynamic blocks to generate repeated configurations
- Complex variable types (list of objects)
- For each with maps
- Building flexible security rules

## Prerequisites

You need a VPC ID to create security groups. You can:
1. Use the VPC from Lab 2
2. Use an existing VPC in your account
3. Create a simple VPC first

## Files in This Lab

| File | Purpose |
|------|---------|
| variables.tf | Complex variable types with list of objects |
| main.tf | Security groups with dynamic blocks |
| outputs.tf | Security group IDs and rule summaries |
| terraform.tfvars | Example ingress rules |

## Steps to Execute

### Step 1: Update VPC ID

Edit terraform.tfvars and replace vpc_id with your actual VPC ID:

```hcl
vpc_id = "vpc-0123456789abcdef0"
```

### Step 2: Initialize Terraform

```bash
terraform init
```

### Step 3: Review the Plan

```bash
terraform plan
```

### Step 4: Apply Configuration

```bash
terraform apply
```

### Step 5: View Outputs

```bash
terraform output
terraform output security_group_ids
terraform output all_ingress_rules_summary
```

## Understanding Dynamic Blocks

Dynamic blocks generate repeated nested blocks from a collection:

```hcl
dynamic "ingress" {
  for_each = var.ingress_rules
  content {
    from_port   = ingress.value.from_port
    to_port     = ingress.value.to_port
    protocol    = ingress.value.protocol
    cidr_blocks = ingress.value.cidr_blocks
  }
}
```

Key points:
- The block name (ingress) becomes the iterator name
- Access values with ingress.value.attribute
- Access index with ingress.key

## Exercises

### Exercise 1: Add a New Rule

Add a custom port rule to web_ingress_rules in terraform.tfvars:

```hcl
web_ingress_rules = [
  # existing rules...
  {
    description = "Custom API port"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
]
```

### Exercise 2: Add a New Security Group

Add a new security group type to the locals.security_groups map.

### Exercise 3: Remove SSH from Production

Modify the dynamic block condition to exclude SSH for production environment.

## Cleanup

```bash
terraform destroy
```
