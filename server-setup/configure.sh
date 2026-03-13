# Handles nginx + duckdns + HTTPS.

#!/bin/bash

set -e
set -o pipefail

source config/variables.conf

LOCAL_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s ifconfig.me)

echo "Local IP: $LOCAL_IP"
echo "Public IP: $PUBLIC_IP"

echo "<h1>Hello World</h1>" | sudo tee /var/www/html/index.html

echo "Disabling default nginx site..."
sudo rm -f /etc/nginx/sites-enabled/default

echo "Installing nginx config..."

sudo cp nginx/vseek.conf /etc/nginx/sites-available/vseek

sudo ln -sf /etc/nginx/sites-available/vseek /etc/nginx/sites-enabled/vseek

sudo nginx -t
sudo systemctl restart nginx

echo "Setting up DuckDNS..."

mkdir -p ~/duckdns

cp duckdns/duck.sh ~/duckdns/

chmod +x ~/duckdns/duck.sh

~/duckdns/duck.sh

(crontab -l 2>/dev/null; echo "*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1") | crontab -

echo "Checking DNS..."

DNS_IP=$(dig +short $DOMAIN | tail -n1)

echo "DuckDNS resolves to: $DNS_IP"

echo ""
echo "Make sure router forwards:"
echo "80 -> $LOCAL_IP"
echo "443 -> $LOCAL_IP"
read -p "Press ENTER when ready..."

echo "Obtaining HTTPS certificate..."

sudo certbot --nginx \
-d $DOMAIN \
--non-interactive \
--agree-tos \
-m $EMAIL \
--redirect

echo "Configuration complete."