# Lab 4 – Enhanced Infrastructure: EC2 with S3

## Overview
This lab demonstrates how to create an EC2 instance with IAM permissions to access an S3 bucket using Terraform.

## Resources Created
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
