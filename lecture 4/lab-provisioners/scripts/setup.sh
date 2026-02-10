#!/bin/bash
# setup.sh - Install and configure web server

set -e

echo "=== Starting Server Setup ==="

# Update system
echo "Updating system packages..."
sudo yum update -y

# Install Apache
echo "Installing Apache..."
sudo yum install -y httpd

# Install additional tools
echo "Installing utilities..."
sudo yum install -y curl wget vim

# Enable and start Apache
echo "Starting Apache..."
sudo systemctl enable httpd
sudo systemctl start httpd

# Create log directory
sudo mkdir -p /var/log/myapp

echo "=== Server Setup Complete ==="
