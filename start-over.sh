# Remove your custom site symlink and config file
sudo rm -f /etc/nginx/sites-enabled/vseek
sudo rm -f /etc/nginx/sites-available/vseek

# Re-enable the default site (if it was disabled)
sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/ 2>/dev/null || true

# Test and reload Nginx
sudo nginx -t && sudo systemctl reload nginx

# Delete the certificate for your domain (replace with your actual domain)
sudo certbot delete --cert-name vseek-server.duckdns.org --non-interactive

# Remove any leftover certbot renewal files (optional)
sudo rm -rf /etc/letsencrypt/live/vseek-server.duckdns.org
sudo rm -rf /etc/letsencrypt/archive/vseek-server.duckdns.org
sudo rm -f /etc/letsencrypt/renewal/vseek-server.duckdns.org.conf

# Remove the cron job
crontab -l | grep -v "duck.sh" | crontab -

# Delete the DuckDNS directory and script
rm -rf ~/duckdns

# Disable UFW
sudo ufw --force disable

# Reset to default deny incoming, allow outgoing (like script defaults)
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Add only SSH and Nginx Full (or OpenSSH) – adjust if you changed SSH port
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'

# Re-enable UFW
sudo ufw --force enable

# Check status
sudo ufw status verbose

# Remove your custom jail.local
sudo rm -f /etc/fail2ban/jail.local

# Restart fail2ban to load defaults
sudo systemctl restart fail2ban

# Remove the test HTML file if you don't need it
sudo rm -f /var/www/html/index.html   # or restore a backup if you had one

# (Optional) Remove any config backups or temporary files you created
sudo apt remove --purge -y nginx ufw fail2ban certbot python3-certbot-nginx glances dnsutils
sudo apt autoremove -y
sudo apt autoclean