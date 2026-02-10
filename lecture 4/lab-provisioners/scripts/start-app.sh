#!/bin/bash
# start-app.sh - Deploy application content

set -e

echo "=== Deploying Application ==="

# Read config
if [ -f /etc/myapp/app.conf ]; then
    source /etc/myapp/app.conf
fi

# Create web content
sudo tee /var/www/html/index.html > /dev/null <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Provisioner Demo</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        .info { background: #e8f4fd; padding: 15px; border-radius: 5px; margin: 10px 0; }
        .success { color: #28a745; }
    </style>
</head>
<body>
    <div class="container">
        <h1 class="success">Provisioner Demo Successful!</h1>
        <p>This web server was configured using Terraform provisioners.</p>
        
        <div class="info">
            <h3>Server Information</h3>
            <p><strong>Hostname:</strong> $(hostname)</p>
            <p><strong>Date:</strong> $(date)</p>
            <p><strong>App Name:</strong> ${APP_NAME:-myapp}</p>
            <p><strong>Environment:</strong> ${APP_ENV:-development}</p>
        </div>
        
        <div class="info">
            <h3>Provisioners Used</h3>
            <ul>
                <li><strong>file</strong> - Copied config and script files</li>
                <li><strong>remote-exec</strong> - Installed and configured Apache</li>
                <li><strong>local-exec</strong> - Logged deployment to local file</li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF

# Restart Apache to apply changes
sudo systemctl restart httpd

echo "=== Application Deployed ==="
echo "Access URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
