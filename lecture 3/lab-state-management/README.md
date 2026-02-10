# Lab 1: State Inspection & Remote Backend

## Objective

Create simple infrastructure and examine the state file to understand how Terraform tracks resources, then configure a remote S3 backend with DynamoDB locking for team collaboration.

## What You Will Learn

- State file structure (JSON format)
- How resources are tracked with serial and lineage
- State backup mechanism
- Creating S3 bucket for state storage with versioning and encryption
- Creating DynamoDB table for state locking
- Configuring Terraform backend and migrating state

## Prerequisites

- AWS credentials configured
- Sufficient IAM permissions for EC2, S3, and DynamoDB

---

## Part A: Inspect State (15 min)

### Step 1: Initialize and Apply

```bash
cd lab-state-management
terraform init
terraform apply
```

### Step 2: Examine the State File

```bash
cat terraform.tfstate | jq
```

### Step 3: Understand State Structure

Look for these key sections:

1. **version**: State file format version
2. **terraform_version**: Terraform version that created this state
3. **serial**: Increments with each change
4. **lineage**: Unique ID for this state file
5. **resources**: Array of all managed resources

### Step 4: Inspect a Specific Resource

```bash
cat terraform.tfstate | jq '.resources[] | select(.type=="aws_instance")'
```

Notice the attributes: id, ami, instance_type, public_ip, private_ip.

### Step 5: Compare with Backup

```bash
cat terraform.tfstate.backup | jq
```

### Step 6: Make a Change and Compare

Update the instance tags in main.tf (add `Updated = "true"`), then apply:

```bash
terraform apply
```

Compare serial numbers:

```bash
echo "Current serial:"
cat terraform.tfstate | jq '.serial'

echo "Backup serial:"
cat terraform.tfstate.backup | jq '.serial'
```

### Step 7: List State Resources

```bash
terraform state list
terraform state show aws_instance.web
terraform output
```

---

## Part B: Configure Remote Backend (20 min)

### Step 8: View Backend Outputs

The infrastructure already includes S3 and DynamoDB resources. Check the outputs:

```bash
terraform output
terraform output backend_config
```

Copy the backend configuration for the next step.

### Step 9: Add Backend Configuration

Create a new file `backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "YOUR-BUCKET-NAME-HERE"
    key            = "demo/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "YOUR-TABLE-NAME-HERE"
  }
}
```

Replace the bucket and table names with values from `terraform output`.

### Step 10: Migrate State to Remote

```bash
terraform init
```

Terraform will detect the backend and ask to migrate. Type `yes`.

### Step 11: Verify Remote State

```bash
aws s3 ls s3://YOUR-BUCKET-NAME/demo/
terraform state list
```

### Step 12: Verify State Locking

In one terminal run `terraform plan`. In another terminal, try `terraform plan` simultaneously. You should see a lock error, proving locking works.

### Step 13: Pull Remote State

```bash
terraform state pull > current-state.json
cat current-state.json | jq
```

---

## Key Observations

1. State is JSON, not HCL
2. State contains ALL resource attributes, not just what you defined
3. Serial increments prevent conflicts
4. Lineage prevents mixing different state files
5. Remote state enables team collaboration
6. S3 versioning provides state history
7. DynamoDB provides state locking

## Important Notes

- Never manually edit terraform.tfstate
- Always use `terraform state` commands for state operations
- Backend configuration cannot use variables (must be literal values)
- Use `-migrate-state` to move state between backends

## Cleanup

1. Remove the backend configuration from `backend.tf`
2. Re-initialize to migrate state back to local:

```bash
terraform init -migrate-state
```

3. Destroy:

```bash
terraform destroy
```
