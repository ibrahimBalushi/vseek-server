#!/bin/bash
# configure.sh - Sets up Nginx, DuckDNS, and HTTPS (without final verification)

set -e
set -o pipefail

# ----------------------------------------------------------------------
# 1. Initial setup: load variables and display IPs
# ----------------------------------------------------------------------
echo "========================================="
echo "  STEP 1: Load configuration"
echo "========================================="
source config/variables.conf

# Verify required variables
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ] || [ -z "$DUCKDNS_DOMAIN" ] || [ -z "$DUCKDNS_TOKEN" ]; then
    echo "❌ Missing required variables in config/variables.conf"
    echo "   Required: DOMAIN, EMAIL, DUCKDNS_DOMAIN, DUCKDNS_TOKEN"
    exit 1
fi

LOCAL_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s ifconfig.me)

echo "Local IP:  $LOCAL_IP"
echo "Public IP: $PUBLIC_IP"
echo "Domain:    $DOMAIN"
echo ""

# ----------------------------------------------------------------------
# 2. Basic HTTP site setup
# ----------------------------------------------------------------------
echo "========================================="
echo "  STEP 2: Configure HTTP site"
echo "========================================="

# Create test page
echo "<h1>Hello World from $DOMAIN</h1>" | sudo tee /var/www/html/index.html > /dev/null

# Disable default site
if [ -f /etc/nginx/sites-enabled/default ]; then
    sudo rm -f /etc/nginx/sites-enabled/default
fi

# Copy HTTP-only nginx config
sudo cp nginx/vseek.conf /etc/nginx/sites-available/vseek
sudo ln -sf /etc/nginx/sites-available/vseek /etc/nginx/sites-enabled/vseek

# Test and restart
sudo nginx -t
sudo systemctl restart nginx

# Verify local access
echo "Verifying local access..."
if curl -s http://localhost | grep -q "Hello World"; then
    echo "✅ Local HTTP test passed."
else
    echo "❌ Local HTTP test failed. Check: sudo journalctl -u nginx"
    exit 1
fi
echo ""

# ----------------------------------------------------------------------
# 3. DuckDNS setup
# ----------------------------------------------------------------------
echo "========================================="
echo "  STEP 3: Configure DuckDNS"
echo "========================================="

mkdir -p ~/duckdns

# Create duck.sh with actual values
cat > ~/duckdns/duck.sh <<EOF
#!/bin/bash
curl -s "https://www.duckdns.org/update?domains=$DUCKDNS_DOMAIN&token=$DUCKDNS_TOKEN&ip="
EOF

chmod +x ~/duckdns/duck.sh

# Run once
echo "Updating DuckDNS..."
UPDATE_RESPONSE=$(~/duckdns/duck.sh)

if [ "$UPDATE_RESPONSE" = "OK" ]; then
    echo "✅ DuckDNS update successful."
else
    echo "❌ DuckDNS update failed with: $UPDATE_RESPONSE"
    echo "   Check token and domain in config/variables.conf"
    exit 1
fi

# Add cron job
echo "Installing cron job..."
(crontab -l 2>/dev/null | grep -v "duck.sh"; echo "*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1") | crontab -
echo "✅ Cron job installed."

# Verify DNS
echo "Checking DNS propagation..."
sleep 3
DNS_IP=$(dig +short "$DOMAIN" | tail -n1)
if [ -n "$DNS_IP" ]; then
    echo "✅ Domain resolves to: $DNS_IP"
else
    echo "⚠️  DNS not yet propagated - will continue"
fi
echo ""

# ----------------------------------------------------------------------
# 4. Port forwarding reminder
# ----------------------------------------------------------------------
echo "========================================="
echo "  STEP 4: Port forwarding required"
echo "========================================="
echo "Forward these ports on your router:"
echo "  80  -> $LOCAL_IP"
echo "  443 -> $LOCAL_IP"
echo ""
read -p "Press ENTER when port forwarding is configured..."
echo ""

# ----------------------------------------------------------------------
# 5. Get SSL certificate
# ----------------------------------------------------------------------
echo "========================================="
echo "  STEP 5: Obtain HTTPS certificate"
echo "========================================="

sudo certbot --nginx \
    -d "$DOMAIN" \
    --non-interactive \
    --agree-tos \
    -m "$EMAIL" \
    --redirect

echo "✅ Certificate obtained."
echo ""

# ----------------------------------------------------------------------
# 6. Done - no verification
# ----------------------------------------------------------------------
echo "========================================="
echo "  Configuration complete!"
echo "========================================="
echo ""
echo "Next step: Run the verification script:"
echo "  ./verify.sh"
echo ""