# Installs and secures the server.

#!/bin/bash

set -e
set -o pipefail

source config/variables.conf

echo "Updating system..."
sudo apt update && sudo apt upgrade -y

echo "Installing packages..."
sudo apt install -y \
nginx \
ufw \
fail2ban \
curl \
certbot \
python3-certbot-nginx \
glances \
dnsutils

echo "Configuring firewall..."

sudo ufw default deny incoming
sudo ufw default allow outgoing

sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'

sudo ufw --force enable

echo "Configuring Fail2Ban..."

sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[sshd]
enabled = true
port = $SSH_PORT
maxretry = 5
EOF

sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

echo "Install phase complete."