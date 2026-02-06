# Lecture 1: Introduction to Terraform and Infrastructure as Code

This guide provides the technical steps required to complete the practical portion of the introduction to Terraform. Follow these steps to deploy an EC2 instance with S3 access.

---

## Lab: EC2 with S3 Access

### Objective
Create an EC2 instance with IAM permissions to access an S3 bucket using Terraform.

### Resources Created
- 1 S3 Bucket (unique name)
- 1 IAM Role + Policy + Instance Profile
- 1 EC2 Instance (t3.micro)

---

### Step 1: Install Terraform

1. Download Terraform from the official distribution for your OS (Windows, macOS, or Linux).
2. Extract the executable and add it to your system PATH.

**For macOS/Linux:**
```bash
mv terraform /usr/local/bin/
```

**Verify installation:**
```bash
terraform --version
```

---

### Step 2: Configure AWS Credentials

Set your AWS access keys as environment variables:
```bash
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
```

---

### Step 3: Create the Project Directory

```bash
mkdir lab-enhanced-infrastructure
cd lab-enhanced-infrastructure
```

---

### Step 4: Write the Infrastructure Code

Create `main.tf` with the following configuration:

```hcl
# Provider Configuration
provider "aws" {
  region = "us-east-1"
}

# Random ID for unique bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket - Your cloud storage
resource "aws_s3_bucket" "lab_bucket" {
  bucket = "terraform-lab-bucket-${random_id.bucket_suffix.hex}"

  tags = {
    Name      = "Terraform-Lab-Bucket"
    CreatedBy = "Terraform"
  }
}

# IAM Role for EC2 to access S3
resource "aws_iam_role" "ec2_s3_role" {
  name = "terraform-lab-ec2-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name      = "Terraform-Lab-EC2-Role"
    CreatedBy = "Terraform"
  }
}

# IAM Policy for S3 access
resource "aws_iam_role_policy" "ec2_s3_policy" {
  name = "terraform-lab-s3-access"
  role = aws_iam_role.ec2_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.lab_bucket.arn,
          "${aws_s3_bucket.lab_bucket.arn}/*"
        ]
      }
    ]
  })
}

# IAM Instance Profile - Attaches role to EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "terraform-lab-ec2-profile"
  role = aws_iam_role.ec2_s3_role.name
}

# EC2 Instance - Your server with S3 access
resource "aws_instance" "my_first_server" {
  ami                    = "ami-0c101f26f147fa7fd"
  instance_type          = "t3.micro"
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name      = "Terraform-Lab-Server"
    CreatedBy = "Terraform"
  }
}

# Outputs - Display important information
output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.my_first_server.id
}

output "instance_public_ip" {
  description = "Public IP of EC2 instance"
  value       = aws_instance.my_first_server.public_ip
}

output "s3_bucket_name" {
  description = "Name of S3 bucket"
  value       = aws_s3_bucket.lab_bucket.id
}
```

---

### Step 5: Deploy the Infrastructure

#### Initialize Terraform
```bash
terraform init
```

#### Review the Plan
```bash
terraform plan
```

#### Apply the Configuration
```bash
terraform apply
```

---

### Step 6: Test S3 Access from EC2

SSH into the instance and verify S3 access:
```bash
ssh -i your-key.pem ec2-user@<instance_public_ip>
aws s3 ls s3://<your-bucket-name>
echo "Hello from EC2" > test.txt
aws s3 cp test.txt s3://<your-bucket-name>/
```

---

### Step 7: Modification Exercise

Change instance type from `t3.micro` to `t3.small` in `main.tf`:
```hcl
instance_type = "t3.small"
```

Then run:
```bash
terraform plan   # See the ~ symbol for update
terraform apply  # Apply the change
```

---

### Step 8: Cleanup

```bash
terraform destroy
```
