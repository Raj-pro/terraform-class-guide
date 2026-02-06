# Lab 4 – Enhanced Infrastructure: EC2 with VPC and S3

## Overview
Building on the "Evolution of a Machine" concept, this lab expands infrastructure to include networking (VPC) and storage (S3).

## Resources Created
- 1 VPC (10.0.0.0/16)
- 1 Internet Gateway
- 1 Subnet (10.0.1.0/24)
- 1 Route Table + Association
- 1 Security Group (SSH allowed)
- 1 S3 Bucket (unique name)
- 1 IAM Role + Policy + Instance Profile
- 1 EC2 Instance (t3.micro)

## Steps to Execute

### 1. Initialize Terraform
```bash
terraform init
```

### 2. Review the Plan
```bash
terraform plan
```

### 3. Apply the Configuration
```bash
terraform apply
```

### 4. Test S3 Access from EC2
```bash
ssh -i your-key.pem ec2-user@<instance_public_ip>
aws s3 ls s3://<your-bucket-name>
echo "Hello from EC2" > test.txt
aws s3 cp test.txt s3://<your-bucket-name>/
```

## Modification Exercise

Change instance type from `t3.micro` to `t3.small` in main.tf:
```hcl
instance_type = "t3.small"  # Changed from t3.micro
```

Then run:
```bash
terraform plan   # See the ~ symbol for update
terraform apply  # Apply the change
```

## Cleanup
```bash
terraform destroy
```

## Security Note
⚠️ The security group allows SSH from any IP (`0.0.0.0/0`). Restrict this in production.
