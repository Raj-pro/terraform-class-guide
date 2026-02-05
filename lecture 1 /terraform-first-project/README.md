# Terraform First Project - Lecture Labs

This directory contains the hands-on lab files for the Introduction to Terraform lecture.

## Prerequisites

1. **Terraform Installation**: Ensure Terraform is installed and available in your PATH
   ```bash
   terraform --version
   ```

2. **AWS Credentials**: Configure your AWS access credentials as environment variables
   ```bash
   export AWS_ACCESS_KEY_ID="your_access_key"
   export AWS_SECRET_ACCESS_KEY="your_secret_key"
   ```

## Lab Workflow

### Lab 2: Project Initialization and Infrastructure Coding

1. Navigate to this directory:
   ```bash
   cd terraform-first-project
   ```

2. Review the `main.tf` file to understand the infrastructure definition

### Lab 3: Deploying and Destroying Resources

1. **Initialize the project**:
   ```bash
   terraform init
   ```

2. **Preview the changes**:
   ```bash
   terraform plan
   ```

3. **Apply the infrastructure**:
   ```bash
   terraform apply
   ```
   Type `yes` when prompted.

4. **Verify in AWS Console**:
   - Navigate to EC2 > Instances
   - Look for instance tagged "Terraform-Lecture-Instance"

5. **Destroy the resource**:
   ```bash
   terraform destroy
   ```
   Type `yes` when prompted.

### Lab 4: Infrastructure Updates and Scaling

1. **Re-apply infrastructure** (if destroyed):
   ```bash
   terraform apply -auto-approve
   ```

2. **Modify the instance size**:
   - Open `main.tf`
   - Change `instance_type` from `"t2.micro"` to `"t3.micro"`
   - Save the file

3. **Preview the update**:
   ```bash
   terraform plan
   ```
   Look for the `~` symbol indicating an in-place update.

4. **Execute the update**:
   ```bash
   terraform apply -auto-approve
   ```

5. **Final cleanup**:
   ```bash
   terraform destroy -auto-approve
   ```

## Files in This Directory

- `main.tf` - Main Terraform configuration file
- `README.md` - This file with instructions
- `setup-credentials.sh` - Helper script to set AWS credentials (Linux/macOS)
- `setup-credentials.bat` - Helper script to set AWS credentials (Windows)

## Important Notes

- Always run `terraform destroy` after completing labs to avoid unnecessary AWS charges
- The AMI ID `ami-0c101f26f147fa7fd` is for us-east-1 region (Amazon Linux 2023)
- If using a different region, update both the `region` in the provider block and the `ami` ID
