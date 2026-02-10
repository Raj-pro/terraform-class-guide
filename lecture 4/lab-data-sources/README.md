# Lab 1: Data Sources and Dependencies

## Objective

Build infrastructure that queries existing resources dynamically and manages dependencies correctly. Learn the difference between implicit and explicit dependencies.

## What You Will Learn

- Using data sources to query AWS account, region, and AMI information
- Fetching available availability zones dynamically
- Understanding implicit dependencies from resource references
- Using explicit depends_on for timing-sensitive resources
- Building a complete VPC with proper dependency ordering

## Resources Created

- VPC with multiple subnets across availability zones
- Internet Gateway with implicit VPC dependency
- NAT Gateway with explicit IGW dependency
- Route tables with proper associations
- Security group for web servers
- EC2 instances using dynamic AMI lookup

## Files in This Lab

| File | Purpose |
|------|---------|
| variables.tf | Input variables for the lab |
| main.tf | Data sources, VPC, subnets, instances |
| outputs.tf | Output values from data sources and resources |
| terraform.tfvars | Default variable values |

---

## Part 1: Understanding Data Sources

### Step 1: Initialize and Explore

```bash
cd lab-data-sources
terraform init
```

### Step 2: View Data Source Values

Before creating resources, see what data sources return:

```bash
terraform plan
```

Look for these data source outputs in the plan:
- Account ID and region
- Available availability zones
- AMI ID and name

### Step 3: Apply Infrastructure

```bash
terraform apply
```

### Step 4: View Outputs

```bash
terraform output
terraform output ami_id
terraform output availability_zones
terraform output infrastructure_summary
```

---

## Part 2: Understanding Dependencies

### Implicit Dependencies

Open main.tf and observe:

1. Internet Gateway depends on VPC (references aws_vpc.main.id)
2. Subnets depend on VPC (references aws_vpc.main.id)
3. EC2 instances depend on subnets and security groups

### Explicit Dependencies

Find the depends_on blocks:

1. EIP depends_on Internet Gateway
2. NAT Gateway depends_on Internet Gateway

Why are these explicit? The NAT gateway needs the IGW to be fully attached to route traffic, but there is no direct resource reference that captures this.

### Step 5: View Dependency Graph

```bash
terraform graph > graph.dot
```

If you have Graphviz installed:

```bash
terraform graph | dot -Tpng > graph.png
```

---

## Part 3: Exercises

### Exercise 1: Add Ubuntu AMI Data Source

Add a data source to fetch the latest Ubuntu 22.04 AMI:

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
```

### Exercise 2: Query Existing VPC

If you have an existing VPC, query it instead of creating one:

```hcl
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Name"
    values = ["my-existing-vpc"]
  }
}
```

### Exercise 3: Add More Explicit Dependencies

Create an RDS instance that needs the NAT gateway for internet access to download updates:

```hcl
resource "aws_db_instance" "example" {
  # ... configuration
  
  depends_on = [aws_nat_gateway.main]
}
```

---

## Cleanup

```bash
terraform destroy
```

---

## Key Takeaways

1. Data sources read existing infrastructure; resources create it
2. Implicit dependencies are automatic from references
3. Use depends_on only when timing matters beyond references
4. Data sources make configurations dynamic and region-agnostic
5. Always check availability zone data before assuming zone names
