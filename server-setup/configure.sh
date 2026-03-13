#!/bin/bash
# configure.sh - Sets up Nginx, DuckDNS, and HTTPS with validation and manual checks
# Follows best practices: HTTP first, then DNS, then port forwarding, finally HTTPS

set -e
set -o pipefail

# ----------------------------------------------------------------------
# 1. Initial setup: load variables and display IPs
# ----------------------------------------------------------------------
echo "========================================="
echo "  STEP 1: Load configuration"
echo "========================================="
source config/variables.conf

LOCAL_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s ifconfig.me)

echo "Local IP:  $LOCAL_IP"
echo "Public IP: $PUBLIC_IP"
echo "Domain:    $DOMAIN"
echo "Email:     $EMAIL"
echo ""

# ----------------------------------------------------------------------
# 2. Basic HTTP site setup (no SSL)
# ----------------------------------------------------------------------
echo "========================================="
echo "  STEP 2: Configure HTTP site"
echo "========================================="

# Create a simple test page
echo "<h1>Hello World from $DOMAIN</h1>" | sudo tee /var/www/html/index.html > /dev/null

# Disable the default nginx site if it exists
if [ -f /etc/nginx/sites-enabled/default ]; then
    echo "Disabling default nginx site..."
    sudo rm -f /etc/nginx/sites-enabled/default
fi

# Copy your custom nginx config (HTTP only version)
echo "Installing nginx configuration..."
sudo cp nginx/vseek.conf /etc/nginx/sites-available/vseek
sudo ln -sf /etc/nginx/sites-available/vseek /etc/nginx/sites-enabled/vseek

# Test and reload nginx
echo "Testing nginx configuration..."
sudo nginx -t
sudo systemctl restart nginx

# Verify local access
echo "Verifying local access to HTTP site..."
if curl -s http://localhost | grep -q "Hello World"; then
    echo "✅ Local HTTP test passed."
else
    echo "❌ Local HTTP test failed. Check nginx logs: sudo journalctl -u nginx"
    exit 1
fi
echo ""

# ----------------------------------------------------------------------
# 3. DuckDNS Dynamic DNS setup
# ----------------------------------------------------------------------
echo "========================================="
echo "  STEP 3: Configure DuckDNS"
echo "========================================="

mkdir -p ~/duckdns

# Copy the duck.sh script (assumes it exists in duckdns/ directory)
if [ ! -f duckdns/duck.sh ]; then
    echo "❌ duckdns/duck.sh not found. Please ensure the file exists."
    exit 1
fi
cp duckdns/duck.sh ~/duckdns/
chmod +x ~/duckdns/duck.sh

# Run it once to update IP
echo "Updating DuckDNS with current public IP..."
~/duckdns/duck.sh

# Add cron job for automatic updates every 5 minutes
echo "Installing cron job for DuckDNS..."
(crontab -l 2>/dev/null | grep -v "duck.sh"; echo "*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1") | crontab -

# Verify DNS resolution
echo "Checking DNS resolution for $DOMAIN..."
sleep 5   # Give DuckDNS a moment to propagate
DNS_IP=$(dig +short "$DOMAIN" | tail -n1)
if [ -n "$DNS_IP" ]; then
    echo "✅ DuckDNS resolves $DOMAIN to $DNS_IP"
    if [ "$DNS_IP" != "$PUBLIC_IP" ]; then
        echo "⚠️  Warning: Resolved IP ($DNS_IP) differs from current public IP ($PUBLIC_IP)."
        echo "   This may be due to slow propagation. Wait a minute and re-run the check."
    fi
else
    echo "❌ DNS resolution failed. Check your DuckDNS token and domain."
    exit 1
fi
echo ""

# ----------------------------------------------------------------------
# 4. Manual step: port forwarding
# ----------------------------------------------------------------------
echo "========================================="
echo "  STEP 4: Configure port forwarding on your router"
echo "========================================="
echo "You must forward ports 80 and 443 to your server's local IP: $LOCAL_IP"
echo ""
echo "Instructions:"
echo " - Log into your router's admin interface."
echo " - Find port forwarding (often under NAT or Advanced)."
echo " - Create two rules:"
echo "     External Port 80  -> Internal IP $LOCAL_IP port 80"
echo "     External Port 443 -> Internal IP $LOCAL_IP port 443"
echo " - Save and apply the settings."
echo ""
echo "After configuring, verify that port 80 is reachable from the internet."
echo "You can use a service like https://canyouseeme.org or run the following"
echo "command from an external network (e.g., a mobile phone):"
echo ""
echo "    curl http://$DOMAIN"
echo ""
read -p "Press ENTER when port forwarding is confirmed to be working..."
echo ""

# ----------------------------------------------------------------------
# 5. Obtain SSL certificate with Certbot
# ----------------------------------------------------------------------
echo "========================================="
echo "  STEP 5: Obtain HTTPS certificate"
echo "========================================="
echo "Requesting certificate for $DOMAIN using Certbot..."
sudo certbot --nginx \
    -d "$DOMAIN" \
    --non-interactive \
    --agree-tos \
    -m "$EMAIL" \
    --redirect

if [ $? -eq 0 ]; then
    echo "✅ Certificate obtained and installed successfully."
else
    echo "❌ Certbot failed. Check /var/log/letsencrypt/letsencrypt.log"
    exit 1
fi
echo ""

# ----------------------------------------------------------------------
# 6. Final verification
# ----------------------------------------------------------------------
echo "========================================="
echo "  STEP 6: Final HTTPS check"
echo "========================================="
echo "Testing HTTPS access..."
if curl -s -k "https://$DOMAIN" | grep -q "Hello World"; then
    echo "✅ HTTPS test passed. Your site is live at https://$DOMAIN"
else
    echo "❌ HTTPS test failed. Check nginx and certificate configuration."
    echo "   Try manually: curl -v https://$DOMAIN"
    exit 1
fi
echo ""

echo "========================================="
echo "  Configuration complete!"
echo "========================================="