# EC2 Module

This module creates an EC2 instance with configurable parameters.

## Usage

```hcl
module "web_server" {
  source = "./modules/ec2"
  
  ami_id             = "ami-0c101f26f147fa7fd"
  instance_type      = "t3.micro"
  subnet_id          = "subnet-abc123"
  security_group_ids = ["sg-abc123"]
  instance_name      = "web-server"
  environment        = "production"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| instance_type | EC2 instance type | string | t3.micro | no |
| ami_id | AMI ID for the instance | string | n/a | yes |
| subnet_id | Subnet ID | string | n/a | yes |
| security_group_ids | Security group IDs | list(string) | [] | no |
| instance_name | Instance name tag | string | n/a | yes |
| environment | Environment name | string | n/a | yes |
| additional_tags | Additional tags | map(string) | {} | no |
| user_data | User data script | string | "" | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | EC2 instance ID |
| instance_arn | EC2 instance ARN |
| public_ip | Public IP address |
| private_ip | Private IP address |
| instance_state | Instance state |
