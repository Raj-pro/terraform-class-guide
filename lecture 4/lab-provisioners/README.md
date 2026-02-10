# Lab 2: Provisioners and Application Deployment

## Objective

Deploy a web application using Terraform provisioners to configure the server after creation. Learn the three types of provisioners: file, remote-exec, and local-exec.

## What You Will Learn

- Creating SSH key pairs for remote access
- Configuring connection blocks for SSH
- Using file provisioner to copy scripts and configs
- Using remote-exec to install software and configure servers
- Using local-exec for local logging and notifications
- Handling provisioner failures
- Destroy-time provisioners

## Prerequisites

Before running this lab, ensure you have:

1. SSH key pair at default locations:
   - Public key: ~/.ssh/id_rsa.pub
   - Private key: ~/.ssh/id_rsa

2. If you do not have SSH keys, generate them:
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
   ```

## Resources Created

- SSH Key Pair in AWS
- VPC with public subnet
- Internet Gateway and Route Table
- Security Group (SSH + HTTP + HTTPS)
- EC2 Instance with provisioners
- Elastic IP for stable access

## Files in This Lab

| File | Purpose |
|------|---------|
| variables.tf | Input variables including SSH key paths |
| main.tf | Infrastructure with provisioners |
| outputs.tf | Connection and access information |
| terraform.tfvars | Default variable values |
| scripts/setup.sh | System setup script |
| scripts/start-app.sh | Application deployment script |
| configs/app.conf | Application configuration |

---

## Part 1: Understanding the Provisioners

### File Provisioner

The file provisioner copies two directories to the remote server:

```hcl
provisioner "file" {
  source      = "${path.module}/configs/"
  destination = "/tmp/configs"
}
```

### Remote-Exec Provisioner

The remote-exec provisioner runs commands on the server:

```hcl
provisioner "remote-exec" {
  inline = [
    "chmod +x /tmp/scripts/*.sh",
    "/tmp/scripts/setup.sh",
    "/tmp/scripts/start-app.sh"
  ]
}
```

### Local-Exec Provisioner

The local-exec provisioner runs commands locally:

```hcl
provisioner "local-exec" {
  command = "echo 'Instance ${self.id} deployed' >> deployment.log"
}
```

---

## Part 2: Running the Lab

### Step 1: Verify SSH Keys

```bash
ls -la ~/.ssh/id_rsa*
```

If keys do not exist, generate them:

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

### Step 2: Initialize Terraform

```bash
cd lab-provisioners
terraform init
```

### Step 3: Review the Plan

```bash
terraform plan
```

Note the provisioners listed in the plan output.

### Step 4: Apply the Configuration

```bash
terraform apply
```

Watch the output carefully. You will see:
1. Resources being created
2. File provisioners copying files
3. Remote-exec provisioner running commands
4. Local-exec provisioner logging

### Step 5: View Outputs

```bash
terraform output
terraform output web_url
terraform output ssh_command
```

### Step 6: Test the Web Server

```bash
curl $(terraform output -raw web_url)
```

Or open the URL in your browser.

### Step 7: SSH to the Instance

```bash
$(terraform output -raw ssh_command)
```

Verify the setup:

```bash
ls /etc/myapp/
cat /etc/myapp/app.conf
systemctl status httpd
```

### Step 8: Check Local Deployment Log

```bash
cat deployment.log
```

---

## Part 3: Exercises

### Exercise 1: Add Health Check Provisioner

Add a local-exec provisioner that waits for the web server to be healthy:

```hcl
provisioner "local-exec" {
  command = <<-EOF
    for i in {1..30}; do
      if curl -s http://${self.public_ip} > /dev/null; then
        echo "Server is healthy!"
        exit 0
      fi
      echo "Waiting for server... ($i/30)"
      sleep 10
    done
    echo "Server health check failed"
    exit 1
  EOF
}
```

### Exercise 2: Add Error Handling

Modify a provisioner to continue on failure:

```hcl
provisioner "remote-exec" {
  on_failure = continue
  inline = [
    "some-command-that-might-fail"
  ]
}
```

### Exercise 3: Use Script Instead of Inline

Replace inline commands with a script reference:

```hcl
provisioner "remote-exec" {
  script = "${path.module}/scripts/complete-setup.sh"
}
```

---

## Cleanup

```bash
terraform destroy
```

Check the deployment.log for the destroy-time provisioner output:

```bash
cat deployment.log
```

---

## Key Takeaways

1. Provisioners are a last resort - prefer user_data or pre-built AMIs
2. Connection blocks configure SSH/WinRM access
3. File provisioners copy files; remote-exec runs commands remotely
4. Local-exec runs commands where Terraform is running
5. Use on_failure = continue for non-critical provisioners
6. Destroy-time provisioners clean up external resources
7. Provisioners only run on creation, not on updates

## Alternative Approaches

For production, consider these alternatives:

1. User Data - Runs at boot without SSH access
2. Packer - Pre-build configured AMIs
3. Ansible - Run via local-exec for complex configuration
4. AWS Systems Manager - Agentless configuration management
