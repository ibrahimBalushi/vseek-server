#!/bin/bash
# =========================================
# Ubuntu Server Bootstrap & Hardening Script
# Author: Ibrahim Al Balush (VSeek Founder)
# Description: Installs and configures Nginx, UFW, Fail2Ban, Certbot,
#              and monitoring tools. Configurable ports via variables.conf.
# =========================================

set -e
set -o pipefail

# -------------------------
# Colors for output
# -------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# -------------------------
# Logging helpers
# -------------------------
info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
header()  { echo -e "\n================== $1 =================="; }

# -------------------------
# Load configuration
# -------------------------
CONFIG_FILE="config/variables.conf"
if [[ ! -f "$CONFIG_FILE" ]]; then
    error "Configuration file $CONFIG_FILE not found!"
    exit 1
fi

source "$CONFIG_FILE"

# Validate required variables
for var in SSH_PORT HTTP_PORT HTTPS_PORT; do
    if [[ -z "${!var}" ]]; then
        error "Variable $var is not set in $CONFIG_FILE"
        exit 1
    fi
done

# -------------------------
# Function: Update & upgrade system
# -------------------------
update_system() {
    header "Updating system"
    sudo apt update -y && sudo apt upgrade -y
}

# -------------------------
# Function: Install packages
# -------------------------
install_packages() {
    header "Installing essential packages"
    sudo apt install -y \
        nginx \
        ufw \
        fail2ban \
        curl \
        certbot \
        python3-certbot-nginx \
        glances \
        dnsutils
}

# -------------------------
# Function: Configure firewall
# -------------------------
configure_firewall() {
    header "Configuring UFW firewall"
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    sudo ufw allow "$SSH_PORT"/tcp
    sudo ufw allow "$HTTP_PORT"/tcp
    sudo ufw allow "$HTTPS_PORT"/tcp

    sudo ufw --force enable
    info "UFW firewall rules applied"
}

# -------------------------
# Function: Configure Fail2Ban
# -------------------------
configure_fail2ban() {
    header "Configuring Fail2Ban for SSH protection"
    sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[sshd]
enabled = true
port = $SSH_PORT
maxretry = 5
EOF

    sudo systemctl enable fail2ban
    sudo systemctl restart fail2ban
    info "Fail2Ban configured and running"
}

# -------------------------
# Main execution
# -------------------------
main() {
    update_system
    install_packages
    configure_firewall
    configure_fail2ban

    header "Installation Complete"
    info "Installed packages and basic server security configured."
    info "SSH Port: $SSH_PORT"
    info "HTTP Port: $HTTP_PORT"
    info "HTTPS Port: $HTTPS_PORT"
}

main