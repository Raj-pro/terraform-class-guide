# Lab 2: Import, Lifecycle & CI/CD

## Objective

Import a manually-created EC2 instance into Terraform, use lifecycle rules to control resource behavior, and set up a GitHub Actions pipeline for automated Terraform workflows.

## What You Will Learn

- Importing existing resources into Terraform state
- `create_before_destroy` for zero downtime
- `prevent_destroy` for critical resources
- `ignore_changes` for external modifications
- Automated CI/CD pipeline with GitHub Actions

---

## Part A: Import Existing EC2 (10 min)

### Prerequisites

Create an EC2 instance manually through AWS Console:
1. Launch instance (Amazon Linux 2023, t3.micro)
2. Name it "manual-instance"
3. Note the instance ID (e.g., i-0abc123def456789)

### Step 1: Write Empty Configuration

Uncomment the `aws_instance.imported` block in `main.tf`.

### Step 2: Import the Instance

```bash
cd lab-import-lifecycle-cicd
terraform init
terraform import aws_instance.imported i-YOUR-INSTANCE-ID
```

### Step 3: View and Verify

```bash
terraform state show aws_instance.imported
terraform plan   # Should show no changes if config matches
```

### Step 4: Add Terraform-managed Tag

Update the tags in the imported resource block and apply:

```bash
terraform apply
```

Now Terraform fully manages the instance!

---

## Part B: Lifecycle Rules (15 min)

### Step 5: Apply Lifecycle Infrastructure

```bash
terraform apply
```

### Step 6: Test create_before_destroy

Change `user_data` in the `aws_instance.web` resource, then:

```bash
terraform apply
```

Terraform creates the new instance BEFORE destroying the old one. Zero downtime!

### Step 7: Test prevent_destroy

```bash
terraform destroy   # Will fail for the S3 bucket
```

Error: "Instance cannot be destroyed" — protecting critical data.

### Step 8: Test ignore_changes

Manually change the `Environment` tag on `aws_instance.external_managed` in AWS Console, then:

```bash
terraform plan   # No changes detected!
```

Terraform ignores the external tag modification.

---

## Part C: CI/CD Pipeline (10 min)

### Step 9: Review the GitHub Actions Workflow

Open `.github/workflows/terraform.yml` and examine the three pipeline stages:

1. **Format & Validate** — Runs on every push/PR
2. **Plan** — Runs on PRs, comments plan on the PR
3. **Apply** — Runs on merge to main, requires manual approval

### Step 10: Set Up Repository (Optional)

```bash
git init
git add .
git commit -m "Initial Terraform setup"
git remote add origin https://github.com/YOUR-USERNAME/terraform-cicd-demo.git
git push -u origin main
```

### Step 11: Add AWS Credentials

1. Go to repo Settings → Secrets → Actions
2. Add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`

### Step 12: Test the Pipeline

Create a feature branch, make a change, push, and create a PR to see the pipeline in action.

---

## Cleanup

```bash
# Remove prevent_destroy from S3 bucket lifecycle block first
terraform destroy
```

## Key Takeaways

1. Import brings existing resources under Terraform without recreation
2. `create_before_destroy` prevents downtime during updates
3. `prevent_destroy` protects critical resources from accidental deletion
4. `ignore_changes` allows external systems to manage specific attributes
5. CI/CD pipelines automate format, validate, plan, and apply workflows
