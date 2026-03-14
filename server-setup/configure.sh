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

# Verify that required variables are set
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ] || [ -z "$DUCKDNS_DOMAIN" ] || [ -z "$DUCKDNS_TOKEN" ]; then
    echo "❌ One or more required variables are missing in config/variables.conf"
    echo "   Please ensure DOMAIN, EMAIL, DUCKDNS_DOMAIN, and DUCKDNS_TOKEN are defined."
    exit 1
fi

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

# Create duck.sh directly with the correct token and domain
cat > ~/duckdns/duck.sh <<EOF
#!/bin/bash
curl -s "https://www.duckdns.org/update?domains=$DUCKDNS_DOMAIN&token=$DUCKDNS_TOKEN&ip="
EOF

chmod +x ~/duckdns/duck.sh

# Run it once and check the response
echo "Updating DuckDNS with current public IP..."
UPDATE_RESPONSE=$(~/duckdns/duck.sh)

if [ "$UPDATE_RESPONSE" = "OK" ]; then
    echo "✅ DuckDNS update successful."
else
    echo "❌ DuckDNS update failed with response: $UPDATE_RESPONSE"
    echo ""
    echo "Possible causes:"
    echo " - Wrong domain or token in config/variables.conf"
    echo "   → Current DUCKDNS_DOMAIN = '$DUCKDNS_DOMAIN'"
    echo "   → Current DUCKDNS_TOKEN  = '$DUCKDNS_TOKEN'"
    echo " - Network issue (cannot reach duckdns.org)"
    echo ""
    echo "To test manually, run:"
    echo "  curl -v \"https://www.duckdns.org/update?domains=$DUCKDNS_DOMAIN&token=$DUCKDNS_TOKEN&ip=\""
    echo ""
    exit 1
fi

# Add cron job – but don't exit on failure
echo "Installing cron job for DuckDNS..."
if (crontab -l 2>/dev/null | grep -v "duck.sh"; echo "*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1") | crontab - ; then
    echo "✅ Cron job installed."
else
    echo "⚠️  Failed to install cron job. You may need to add it manually:"
    echo "   */5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1"
    # Continue anyway – DuckDNS update succeeded
fi

# Verify DNS resolution (optional, but helpful)
if command -v dig &> /dev/null; then
    echo "Checking DNS resolution for $DOMAIN..."
    sleep 5
    DNS_IP=$(dig +short "$DOMAIN" | tail -n1)
    if [ -n "$DNS_IP" ]; then
        echo "✅ DuckDNS resolves $DOMAIN to $DNS_IP"
    else
        echo "⚠️  DNS resolution failed – but update succeeded. This may take a few minutes."
    fi
else
    echo "⚠️  'dig' not found – skipping DNS resolution check."
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
echo "     External Port $HTTP_PORT  -> Internal IP $LOCAL_IP port 80"
echo "     External Port $HTTPS_PORT -> Internal IP $LOCAL_IP port 443"
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
echo "  STEP 5: Configure HTTPS Certificate"
echo "========================================="

CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"

# -----------------------------
# If certificate already exists
# -----------------------------
if [ -f "$CERT_PATH" ]; then
    echo "✅ Existing certificate found for $DOMAIN"
    echo "Skipping new certificate request."

else
    echo "No certificate found."

    # -----------------------------
    # Use staging mode if requested
    # -----------------------------
    if [ "$USE_STAGING" = true ]; then
        echo "Using Let's Encrypt STAGING environment"
        STAGING_FLAG="--staging"
    else
        STAGING_FLAG=""
    fi

    echo "Requesting certificate for $DOMAIN..."

    sudo certbot --nginx \
        $STAGING_FLAG \
        -d "$DOMAIN" \
        --non-interactive \
        --agree-tos \
        -m "$EMAIL" \
        --redirect

    if [ $? -eq 0 ]; then
        echo "✅ Certificate successfully installed."
    else
        echo "❌ Certbot failed."
        echo "Check log: /var/log/letsencrypt/letsencrypt.log"
        exit 1
    fi
fi

# -----------------------------
# Test and reload nginx
# -----------------------------
echo "Testing nginx configuration..."
sudo nginx -t

echo "Reloading nginx..."
sudo systemctl reload nginx

echo "✅ HTTPS setup complete."
echo ""

# # ----------------------------------------------------------------------
# # 6. Final verification
# # ----------------------------------------------------------------------
# echo "========================================="
# echo "  STEP 6: Final HTTPS check"
# echo "========================================="
# echo "Testing HTTPS access..."
# if curl -s -k "https://$DOMAIN" | grep -q "Hello World"; then
#     echo "✅ HTTPS test passed. Your site is live at https://$DOMAIN"
# else
#     echo "❌ HTTPS test failed. Check nginx and certificate configuration."
#     echo "   Try manually: curl -v https://$DOMAIN"
#     exit 1
# fi
# echo ""

# echo "========================================="
# echo "  Configuration complete!"
# echo "========================================="