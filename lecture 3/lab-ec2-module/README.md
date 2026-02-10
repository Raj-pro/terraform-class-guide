# Lab 2: Build, Use & Reuse EC2 Module

## Objective

Build a reusable EC2 module with variables and outputs, call it from a root configuration, then reuse the same module to deploy both dev and prod environments.

## What You Will Learn

- Module directory structure and encapsulation
- Input variables and output values
- Calling modules with the `module` block
- Passing variables and accessing module outputs
- Reusing the same module for multiple environments
- DRY (Don't Repeat Yourself) principles

## Architecture

```
lab-ec2-module/
├── modules/ec2/          # Part A: The reusable module
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── README.md
├── main.tf               # Parts B & C: Root config using the module
├── variables.tf
└── outputs.tf
```

```
Shared VPC (10.0.0.0/16)
├── Dev Subnet (10.0.1.0/24)
│   └── Dev Server (t3.micro)
└── Prod Subnet (10.0.2.0/24)
    └── Prod Server (t3.small)
```

---

## Part A: Create the Module (15 min)

### Step 1: Review Module Files

```bash
cd lab-ec2-module
tree modules/ec2/
```

### Step 2: Understand Module Variables

Open `modules/ec2/variables.tf` and note:
- Required variables (no default): ami_id, subnet_id, instance_name, environment
- Optional variables (with default): instance_type, security_group_ids, additional_tags, user_data
- Variable types and descriptions

### Step 3: Understand Module Outputs

Open `modules/ec2/outputs.tf` and see what values the module exposes:
- instance_id, instance_arn, public_ip, private_ip, instance_state

### Step 4: Read Module Documentation

Open `modules/ec2/README.md` to see the usage guide, inputs table, and outputs table.

### Key Concepts

1. **Encapsulation**: Module hides implementation details
2. **Reusability**: Same module can be used multiple times
3. **Configurability**: Variables make module flexible
4. **Outputs**: Module exposes useful information

---

## Part B: Use the Module (10 min)

### Step 5: Review Root Configuration

Open `main.tf` and examine how the module is called:

```hcl
module "dev_server" {
  source = "./modules/ec2"
  
  ami_id             = data.aws_ami.amazon_linux.id
  instance_type      = "t3.micro"
  subnet_id          = aws_subnet.dev.id
  security_group_ids = [aws_security_group.dev.id]
  instance_name      = "dev-web-server"
  environment        = "dev"
}
```

Note:
- `source`: Path to the module
- All other arguments are module input variables

### Step 6: Initialize and Apply

```bash
terraform init
terraform plan
```

Notice how module resources are prefixed with `module.dev_server.`

```bash
terraform apply
```

### Step 7: View Outputs and State

```bash
terraform output
terraform state list
terraform state show module.dev_server.aws_instance.this
```

---

## Part C: Reuse for Dev & Prod (15 min)

### Step 8: Compare Module Calls

In `main.tf`, notice the same module is called twice with different configs:

| Configuration | Dev | Prod |
|---------------|-----|------|
| Instance Type | t3.micro | t3.small |
| SSH Access | Allowed | Blocked |
| Tags | Minimal | Compliance tags |

### Step 9: Test Both Servers

```bash
# Test dev server
curl $(terraform output -raw dev_server_url)

# Test prod server
curl $(terraform output -raw prod_server_url)
```

### Step 10: Inspect State

```bash
terraform state list
```

Output:
```
module.dev_server.aws_instance.this
module.prod_server.aws_instance.this
```

Same module code, two separate instances in state!

### Step 11: Compare Configurations

```bash
terraform state show module.dev_server.aws_instance.this | grep instance_type
terraform state show module.prod_server.aws_instance.this | grep instance_type
```

---

## Key Takeaways

1. **Write Once, Use Many**: Module code is written once
2. **Consistency**: Same patterns across environments
3. **Easy Updates**: Fix bugs in one place
4. **Testable**: Test module in dev, deploy to prod
5. Modules enable code reuse across environments
6. Same module, different configurations

## Cleanup

```bash
terraform destroy
```
