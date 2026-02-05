# Lecture 1 Hands-On Guide From Installation to Deployment

This guide provides the technical steps required to complete the practical portion of the introduction to Terraform. Follow these steps sequentially to move from an empty machine to a fully provisioned cloud environment.

---

## Lab 1 Setting Up the Environment

### Objective
Install the Terraform binary on your local workstation and verify that the operating system can execute Terraform commands.

### Step 1: Download and Install
1. Access the official Terraform distribution.
2. Select the package that matches your operating system (Windows, macOS, or Linux).
3. Download the ZIP archive and extract the executable file named `terraform`.

### Step 2: Configure System PATH
To ensure you can run Terraform from any directory, you must move the binary to a folder included in your system's PATH.

**For Windows:**
1. Move `terraform.exe` to a folder like `C:\terraform`.
2. Open System Environment Variables.
3. Edit the `Path` variable and add `C:\terraform`.

**For macOS/Linux:**
1. Move the `terraform` binary to `/usr/local/bin/` using the move command.
```bash
mv terraform /usr/local/bin/
```

### Step 3: Verify Installation
1. Open a new terminal window or command prompt.
2. Type the version command to confirm the system recognizes the tool.
```bash
terraform --version
```
3. Ensure the output displays the version number without any error messages.

---

## Lab 2 Project Initialization and Infrastructure Coding

### Objective
Establish the directory structure for your first project and write the configuration code necessary to define an AWS EC2 instance.

### Step 1: Create the Project Directory
Create a dedicated space for your infrastructure code to keep the state files organized.
1. Create a folder named `terraform-first-project`.
2. Enter that folder in your terminal.
```bash
mkdir terraform-first-project
cd terraform-first-project
```

### Step 2: Configure AWS Credentials
Before running code, Terraform needs permission to talk to your AWS account. Set your access keys as environment variables in your terminal.
```bash
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
```

### Step 3: Create the Configuration File
1. Inside your folder, create a new file named `main.tf`.
2. Open the file in a text editor (e.g., VS Code, Notepad++, or Vim).

### Step 4: Write the Provider and Resource Block
Paste the following code into `main.tf`. This specifies that we are using AWS and want to build one virtual server.

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "lab_server" {
  ami           = "ami-0c101f26f147fa7fd"
  instance_type = "t2.micro"

  tags = {
    Name = "Terraform-Lecture-Instance"
  }
}
```

---

## Lab 3 Deploying and Destroying Resources

### Objective
Execute the standard Terraform lifecycle commands to move your code from a local file to a live resource in the cloud.

### Step 1: Initialize the Project
Run the init command to download the AWS provider plugin.
```bash
terraform init
```

### Step 2: Preview the Changes
Run the plan command to see what Terraform intends to do. Look for the message `Plan: 1 to add, 0 to change, 0 to destroy`.
```bash
terraform plan
```

### Step 3: Apply the Infrastructure
Execute the plan and type `yes` when prompted for confirmation.
```bash
terraform apply
```

### Step 4: Verify in Cloud Console
1. Log into your AWS Console.
2. Navigate to EC2 > Instances.
3. Locate the instance with the tag "Terraform-Lecture-Instance".

### Step 5: Destroy the Resource
Remove the server to avoid unnecessary costs.
```bash
terraform destroy
```
Type `yes` when prompted. Verify in the AWS console that the instance status has changed to "Terminating."

---

## Lab 4 Infrastructure Updates and Scaling

### Objective
Observe how Terraform handles changes to existing infrastructure using the "update in-place" logic.

### Step 1: Re-apply Initial Infrastructure
If you destroyed your instance in the previous lab, run apply again to bring it back.
```bash
terraform apply -auto-approve
```

### Step 2: Modify the Instance Size
1. Open your `main.tf` file.
2. Locate the `instance_type` line.
3. Change the value from `"t2.micro"` to `"t3.micro"`.
4. Save the file.

### Step 3: Preview the Update
Run the plan command. Observe that the output shows a `~` (tilde) symbol, indicating an update rather than a full replacement.
```bash
terraform plan
```

### Step 4: Execute the Update
Run the apply command.
```bash
terraform apply -auto-approve
```
Terraform will coordinate the change with the AWS API.

### Step 5: Final Cleanup
Once you have confirmed the instance type has changed in the AWS console, run the final destroy command to leave your account clean.
```bash
terraform destroy -auto-approve
```
