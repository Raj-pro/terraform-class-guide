output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Instance public IP (from EIP)"
  value       = aws_eip.web.public_ip
}

output "private_ip" {
  description = "Instance private IP"
  value       = aws_instance.web.private_ip
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ${var.ssh_private_key_path} ec2-user@${aws_eip.web.public_ip}"
}

output "web_url" {
  description = "Web server URL"
  value       = "http://${aws_eip.web.public_ip}"
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.web.id
}

output "key_name" {
  description = "SSH key pair name"
  value       = aws_key_pair.deployer.key_name
}
