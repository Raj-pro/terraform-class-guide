#!/bin/bash

# AWS Credentials Setup Script for Linux/macOS
# This script helps you set up AWS credentials as environment variables

echo "=== AWS Credentials Setup ==="
echo ""
echo "This script will set your AWS credentials as environment variables."
echo "Note: These credentials will only persist for the current terminal session."
echo ""

# Prompt for AWS Access Key ID
read -p "Enter your AWS Access Key ID: " aws_access_key
export AWS_ACCESS_KEY_ID="$aws_access_key"

# Prompt for AWS Secret Access Key (hidden input)
read -sp "Enter your AWS Secret Access Key: " aws_secret_key
echo ""
export AWS_SECRET_ACCESS_KEY="$aws_secret_key"

echo ""
echo "✓ AWS credentials have been set for this terminal session."
echo ""
echo "You can now run Terraform commands:"
echo "  terraform init"
echo "  terraform plan"
echo "  terraform apply"
echo ""
echo "To verify your credentials are set, run:"
echo "  echo \$AWS_ACCESS_KEY_ID"
echo ""
