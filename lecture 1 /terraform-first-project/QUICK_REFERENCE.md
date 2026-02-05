# Terraform Lecture 1 - Quick Reference

## Lab 1: Installation Verification

```bash
# Check Terraform installation
terraform --version
```

Expected output: `Terraform v1.x.x` (or similar)

---

## Lab 2: Project Setup

```bash
# Create and navigate to project directory
mkdir terraform-first-project
cd terraform-first-project

# Set AWS credentials (Linux/macOS)
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"

# Or use the helper script
source setup-credentials.sh
```

**Configuration File**: `main.tf` (already created)

---

## Lab 3: Deploy and Destroy

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply infrastructure
terraform apply
# Type 'yes' when prompted

# Verify in AWS Console
# EC2 > Instances > Look for "Terraform-Lecture-Instance"

# Destroy infrastructure
terraform destroy
# Type 'yes' when prompted
```

---

## Lab 4: Update Infrastructure

```bash
# Re-deploy if needed
terraform apply -auto-approve

# Edit main.tf: Change instance_type from "t2.micro" to "t3.micro"

# Preview the update
terraform plan
# Look for '~' symbol (update in-place)

# Apply the update
terraform apply -auto-approve

# Final cleanup
terraform destroy -auto-approve
```

---

## Common Commands

| Command | Purpose |
|---------|---------|
| `terraform init` | Download provider plugins and initialize backend |
| `terraform plan` | Preview changes without applying |
| `terraform apply` | Create/update infrastructure |
| `terraform destroy` | Remove all managed infrastructure |
| `terraform fmt` | Format configuration files |
| `terraform validate` | Validate configuration syntax |
| `terraform show` | Display current state |

---

## Troubleshooting

### Issue: "No valid credential sources found"
**Solution**: Ensure AWS credentials are set as environment variables

### Issue: "Error launching source instance: InvalidAMIID.NotFound"
**Solution**: The AMI ID may not be available in your region. Update the AMI ID in `main.tf`

### Issue: "terraform: command not found"
**Solution**: Ensure Terraform binary is in your system PATH

---

## Cost Warning

⚠️ **Always run `terraform destroy` after completing labs to avoid AWS charges!**

The t2.micro instance is free-tier eligible, but leaving resources running can incur costs.
