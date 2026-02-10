# Lab 1: Workspaces & Workspace Variables

## Objective

Create and manage multiple Terraform workspaces, then use workspace-specific configurations with locals to deploy different infrastructure per environment.

## What You Will Learn

- Creating and switching workspaces
- Workspace-specific state files
- Using `terraform.workspace` variable
- Environment-specific variables via locals maps
- Conditional resource sizing per workspace

## Configuration Map

| Setting | Dev | Staging | Prod |
|---------|-----|---------|------|
| instance_type | t3.micro | t3.small | t3.medium |
| instance_count | 1 | 2 | 3 |
| monitoring | false | true | true |

---

## Part A: Create Workspaces (15 min)

### Step 1: Initialize

```bash
cd lab-workspaces
terraform init
terraform workspace show   # Shows "default"
```

### Step 2: Create Workspaces

```bash
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod
terraform workspace list
```

### Step 3: Apply in Dev

```bash
terraform workspace select dev
terraform apply
terraform output
```

Resources are created with "dev" prefix and t3.micro instance type.

### Step 4: Apply in Prod

```bash
terraform workspace select prod
terraform apply
terraform output
```

Notice: 3 instances of t3.medium with monitoring enabled!

### Step 5: View State Files

```bash
ls -la terraform.tfstate.d/
```

Each workspace has its own state file.

---

## Part B: Compare Workspace Variables (15 min)

### Step 6: Compare Outputs Across Workspaces

```bash
terraform workspace select dev && terraform output
terraform workspace select staging && terraform output
terraform workspace select prod && terraform output
```

Compare instance_type, instance_count, and IPs across environments.

### Step 7: Switch Between Workspaces

```bash
terraform workspace select dev
terraform state list    # 1 instance

terraform workspace select prod
terraform state list    # 3 instances
```

Same code, different infrastructure!

### Step 8: Review the Locals Map

Open `variables.tf` and examine how the `workspace_config` map drives all differences between environments.

---

## Cleanup

```bash
# Destroy each workspace
terraform workspace select dev && terraform destroy
terraform workspace select staging && terraform destroy
terraform workspace select prod && terraform destroy

# Delete workspaces
terraform workspace select default
terraform workspace delete dev
terraform workspace delete staging
terraform workspace delete prod
```

## Key Takeaways

1. Each workspace has independent state
2. `terraform.workspace` provides the current workspace name
3. Use locals with maps for workspace-specific configs
4. Different instance counts and types per environment
5. Always check current workspace before applying
