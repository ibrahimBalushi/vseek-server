#!/bin/bash
# =========================================
# Fully Automated Ubuntu Server Setup Script
# UFW + Fail2Ban + Nginx + DuckDNS + HTTPS
# =========================================

# -------------------------
# CONFIGURATION VARIABLES
# -------------------------
DUCKDNS_DOMAIN="vseek-server"
DUCKDNS_TOKEN="6a038e16-8027-4245-b012-dd577dafbea7"     # <-- replace with your token
EMAIL_CERTBOT="abraham.rakji@gmail.com"                  # <-- replace with your email
SSH_PORT=22
WIFI_SSID="Balusky"                                      # <-- replace with your SSID
WIFI_PASSWORD="19860112"                                 # <-- replace with your password

# -------------------------
# UPDATE SYSTEM
# -------------------------
echo "Updating system..."
sudo apt update && sudo apt upgrade -y

# -------------------------
# INSTALL ESSENTIAL PACKAGES
# -------------------------
echo "Installing essential packages..."
sudo apt install -y ufw fail2ban nginx curl certbot python3-certbot-nginx netplan.io glances

# -------------------------
# CONFIGURE FIREWALL
# -------------------------
echo "Configuring UFW firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow $SSH_PORT/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# -------------------------
# CONFIGURE FAIL2BAN
# -------------------------
echo "Configuring Fail2Ban..."
sudo tee /etc/fail2ban/jail.local > /dev/null <<EOL
[sshd]
enabled = true
port = $SSH_PORT
logpath = /var/log/auth.log
maxretry = 5
EOL
sudo systemctl restart fail2ban
sudo systemctl enable fail2ban

# -------------------------
# WIFI CONFIGURATION
# -------------------------
echo "Writing Wi-Fi configuration..."
sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null <<EOL
network:
    version: 2
    wifis:
        wlp1s0:
            dhcp4: true
            access-points:
                "$WIFI_SSID":
                    password: "$WIFI_PASSWORD"
EOL

sudo netplan apply

# -------------------------
# CREATE HELLO WORLD PAGE
# -------------------------
echo "<h1>Hello World</h1>" | sudo tee /var/www/html/index.html

# -------------------------
# CREATE DUCKDNS SCRIPT
# -------------------------
echo "Creating DuckDNS updater script..."
mkdir -p ~/duckdns
tee ~/duckdns/duck.sh > /dev/null <<EOL
#!/bin/bash
curl "https://www.duckdns.org/update?domains=$DUCKDNS_DOMAIN&token=$DUCKDNS_TOKEN&ip="
EOL
chmod +x ~/duckdns/duck.sh

# -------------------------
# CRON JOB FOR DUCKDNS
# -------------------------
echo "Adding cron job to update DuckDNS every 5 minutes..."
(crontab -l 2>/dev/null; echo "*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1") | crontab -

# -------------------------
# TEMPORARY HTTP NGINX CONFIG
# -------------------------
echo "Writing temporary HTTP-only Nginx config for Certbot..."
sudo tee /etc/nginx/sites-available/vseek_temp > /dev/null <<EOL
server {
    listen 80;
    server_name $DUCKDNS_DOMAIN.duckdns.org;

    root /var/www/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOL

sudo ln -sf /etc/nginx/sites-available/vseek_temp /etc/nginx/sites-enabled/vseek
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

# -------------------------
# VERIFY PORTS BEFORE CERTBOT
# -------------------------
echo "Ensuring firewall allows HTTP/HTTPS..."
sudo ufw allow 'Nginx Full'
sudo ufw reload

# Optional external check (cannot automate fully)
echo "Ensure that your router is forwarding ports 80/443 to this server."
# -------------------------
# ROUTER PORT FORWARDING PAUSE
# -------------------------
echo ""
echo "==========================================="
echo "MANUAL STEP REQUIRED"
echo ""
echo "Before continuing you must forward ports"
echo "in your router to this server."
echo ""
echo "Forward the following ports:"
echo "  TCP 80  -> this server (HTTP)"
echo "  TCP 443 -> this server (HTTPS)"
echo ""
echo "Router should forward to this machine's"
echo "local IP address."
echo ""
echo "You can check your IP with:"
echo "  ip a"
echo ""
echo "Once port forwarding is complete,"
echo "press ENTER to continue..."
echo "==========================================="
read -p ""

# -------------------------
# OBTAIN HTTPS CERTIFICATE
# -------------------------
echo "Running Certbot to obtain HTTPS certificate..."
sudo certbot --nginx -d $DUCKDNS_DOMAIN.duckdns.org --non-interactive --agree-tos -m $EMAIL_CERTBOT || {
    echo "Certbot failed! Make sure port 80 is reachable from the internet."
    exit 1
}

# -------------------------
# FINAL NGINX CONFIG WITH HTTPS
# -------------------------
echo "Writing final HTTPS Nginx config..."
sudo tee /etc/nginx/sites-available/vseek > /dev/null <<EOL
# HTTP redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $DUCKDNS_DOMAIN.duckdns.org;

    return 301 https://\$host\$request_uri;
}

# HTTPS server
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name $DUCKDNS_DOMAIN.duckdns.org;

    root /var/www/html;
    index index.html;

    ssl_certificate /etc/letsencrypt/live/$DUCKDNS_DOMAIN.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DUCKDNS_DOMAIN.duckdns.org/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOL

sudo ln -sf /etc/nginx/sites-available/vseek /etc/nginx/sites-enabled/vseek
sudo nginx -t
sudo systemctl reload nginx

# -------------------------
# FINISHED
# -------------------------
echo "====================================="
echo "Setup complete!"
echo "Website: https://$DUCKDNS_DOMAIN.duckdns.org"
echo "SSH port: $SSH_PORT"
echo "UFW status:"
sudo ufw status verbose
echo "Fail2Ban status:"
sudo fail2ban-client status sshd
echo "DuckDNS updater script: ~/duckdns/duck.sh"
echo "Cron job updates DuckDNS every 5 minutes"
echo "====================================="