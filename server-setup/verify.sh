# verification script should check connectivity layer by layer:
# 1. Server services
# 2. Local HTTP
# 3. DNS resolution
# 4. Public IP detection
# 5. Public HTTP connectivity
# 6. Public HTTPS connectivity
# 7. Port reachability

#!/bin/bash
#!/bin/bash
# verify.sh - Comprehensive diagnostic tool for DuckDNS + Nginx + HTTPS setup
# Run this script to test all components and identify issues

set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ----------------------------------------------------------------------
# Helper functions
# ----------------------------------------------------------------------
print_header() {
    echo ""
    echo "========================================="
    echo "  $1"
    echo "========================================="
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_divider() {
    echo "-----------------------------------------"
}

# ----------------------------------------------------------------------
# Load configuration
# ----------------------------------------------------------------------
print_header "Loading Configuration"

if [ -f config/variables.conf ]; then
    source config/variables.conf
    print_success "Configuration loaded from config/variables.conf"
else
    print_error "config/variables.conf not found"
    exit 1
fi

# Get IP addresses
LOCAL_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null)

print_info "Local IP:  $LOCAL_IP"
print_info "Public IP: $PUBLIC_IP"
print_info "Domain:    $DOMAIN"
print_divider

# ----------------------------------------------------------------------
# Test 1: Nginx status and configuration
# ----------------------------------------------------------------------
print_header "Test 1: Nginx Status"

# Check if nginx is running
if systemctl is-active --quiet nginx; then
    print_success "Nginx is running"
else
    print_error "Nginx is not running"
    print_info "Try: sudo systemctl start nginx"
fi

# Test nginx configuration
if sudo nginx -t 2>&1 >/dev/null; then
    print_success "Nginx configuration is valid"
else
    print_error "Nginx configuration has errors"
    print_info "Run: sudo nginx -t to see details"
fi

# Check listening ports
print_info "Checking listening ports..."
PORTS=$(sudo ss -tlnp | grep -E ':(80|443|8443)')
if echo "$PORTS" | grep -q ":80"; then
    print_success "Port 80 is listening"
else
    print_error "Port 80 is not listening"
fi

if echo "$PORTS" | grep -q ":443"; then
    print_success "Port 443 is listening"
else
    print_error "Port 443 is not listening"
fi

print_divider

# ----------------------------------------------------------------------
# Test 2: Firewall Configuration
# ----------------------------------------------------------------------
print_header "Test 2: Firewall Status"

if sudo ufw status | grep -q "Status: active"; then
    print_success "UFW firewall is active"
    
    # Check if ports are allowed
    if sudo ufw status | grep -q "80/tcp"; then
        print_success "Port 80/tcp is allowed"
    else
        print_warning "Port 80/tcp may not be allowed"
    fi
    
    if sudo ufw status | grep -q "443/tcp"; then
        print_success "Port 443/tcp is allowed"
    else
        print_warning "Port 443/tcp may not be allowed"
    fi
    
    # Show full status
    print_info "Current UFW rules:"
    sudo ufw status | grep -v "Status:" | sed 's/^/    /'
else
    print_warning "UFW firewall is not active"
fi

print_divider

# ----------------------------------------------------------------------
# Test 3: Local HTTPS Access
# ----------------------------------------------------------------------
print_header "Test 3: Local HTTPS Access"

# Test localhost
if curl -k -s --max-time 5 https://localhost | grep -q "Hello World"; then
    print_success "Localhost HTTPS works"
else
    print_error "Cannot access https://localhost"
fi

# Test local IP
if curl -k -s --max-time 5 https://$LOCAL_IP | grep -q "Hello World"; then
    print_success "Local IP HTTPS works"
else
    print_error "Cannot access https://$LOCAL_IP"
fi

print_divider

# ----------------------------------------------------------------------
# Test: NAT Hairpin/Loopback Detection
# ----------------------------------------------------------------------
print_header "Test: NAT Hairpin Support"

print_info "Testing if router supports NAT hairpin..."
if curl -k -s --max-time 5 "https://$PUBLIC_IP" | grep -q "Hello World"; then
    print_success "Router supports NAT hairpin - internal access via public IP works!"
else
    print_warning "Router does NOT support NAT hairpin"
    print_info "This is normal - many consumer routers lack this feature."
    print_info ""
    print_info "To access your server from INSIDE your network:"
    print_info "  1. Use local IP directly: https://$LOCAL_IP"
    print_info "  2. Or add to /etc/hosts: $LOCAL_IP $DOMAIN"
    print_info "  3. Or check router for 'NAT Loopback' setting"
    echo ""
    
    # Test if hosts file already has entry
    if grep -q "$DOMAIN" /etc/hosts; then
        HOSTS_IP=$(grep "$DOMAIN" /etc/hosts | awk '{print $1}')
        if [ "$HOSTS_IP" = "$LOCAL_IP" ]; then
            print_success "Hosts file already configured correctly"
        else
            print_warning "Hosts file has wrong IP for $DOMAIN: $HOSTS_IP (should be $LOCAL_IP)"
        fi
    else
        print_info "To fix temporarily, run:"
        print_info "  echo \"$LOCAL_IP $DOMAIN\" | sudo tee -a /etc/hosts"
    fi
fi
print_divider

# ----------------------------------------------------------------------
# Step : NAT Hairpin Test
# ----------------------------------------------------------------------
print_header "Test: internal domain access"

echo "Testing if you can access https://$DOMAIN from this machine..."
if curl -k -s --max-time 5 "https://$DOMAIN" | grep -q "Hello World"; then
    echo "✅ Success! Your router supports NAT hairpin."
else
    echo "⚠️  Cannot access domain from inside your network."
    echo ""
    echo "This is normal if your router doesn't support NAT hairpin."
    echo "To access your server locally using the domain name:"
    echo ""
    echo "  echo \"$LOCAL_IP $DOMAIN\" | sudo tee -a /etc/hosts"
    echo ""
    echo "Or use the local IP directly: https://$LOCAL_IP"
fi
echo ""

# ----------------------------------------------------------------------
# Test 4: DuckDNS Resolution
# ----------------------------------------------------------------------
print_header "Test 4: DuckDNS Resolution"

# Check if dig is installed
if ! command -v dig &> /dev/null; then
    print_info "Installing dnsutils for dig command..."
    sudo apt update && sudo apt install dnsutils -y
fi

# Resolve domain
DNS_IP=$(dig +short "$DOMAIN" | tail -n1)
if [ -n "$DNS_IP" ]; then
    print_success "$DOMAIN resolves to $DNS_IP"
    
    # Compare with public IP
    if [ "$DNS_IP" = "$PUBLIC_IP" ]; then
        print_success "DNS IP matches current public IP"
    else
        print_warning "DNS IP ($DNS_IP) differs from public IP ($PUBLIC_IP)"
        print_info "DuckDNS may need update. Run: ~/duckdns/duck.sh"
    fi
else
    print_error "$DOMAIN does not resolve"
    print_info "Check your DuckDNS configuration"
fi

# Check DuckDNS cron job
if crontab -l 2>/dev/null | grep -q "duck.sh"; then
    print_success "DuckDNS cron job is installed"
    print_info "Cron entry: $(crontab -l | grep duck.sh)"
else
    print_warning "No DuckDNS cron job found"
    print_info "Add with: crontab -e"
fi

print_divider

# ----------------------------------------------------------------------
# Test 5: NAT Loopback (Server to Public IP)
# ----------------------------------------------------------------------
print_header "Test 5: NAT Loopback Test"

print_info "Testing if server can reach itself via public IP..."
if curl -4 -k -s --max-time 5 "https://$PUBLIC_IP" | grep -q "Hello World"; then
    print_success "NAT loopback works - server can reach itself via public IP"
else
    print_warning "NAT loopback failed - this is normal for many routers"
    print_info "This doesn't necessarily mean external access is broken"
fi

print_divider

# ----------------------------------------------------------------------
# Test 6: SSL Certificate Check
# ----------------------------------------------------------------------
print_header "Test 6: SSL Certificate"

# Check for Let's Encrypt certificate
if [ -d /etc/letsencrypt/live/$DOMAIN ]; then
    print_success "Let's Encrypt certificate found"
    
    # Check expiration
    if [ -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem ]; then
        EXPIRY=$(sudo openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -noout -enddate | cut -d= -f2)
        print_info "Certificate expires: $EXPIRY"
        
        # Calculate days until expiry
        EXPIRY_EPOCH=$(sudo openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -noout -enddate | cut -d= -f2 | date -d "$(cat)" +%s 2>/dev/null || echo "unknown")
        if [ "$EXPIRY_EPOCH" != "unknown" ]; then
            NOW_EPOCH=$(date +%s)
            DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))
            if [ $DAYS_LEFT -lt 30 ]; then
                print_warning "Certificate expires in $DAYS_LEFT days"
            else
                print_success "Certificate valid for $DAYS_LEFT more days"
            fi
        fi
    fi
elif [ -f /etc/nginx/ssl/selfsigned.crt ]; then
    print_warning "Using self-signed certificate"
    EXPIRY=$(sudo openssl x509 -in /etc/nginx/ssl/selfsigned.crt -noout -enddate | cut -d= -f2)
    print_info "Self-signed cert expires: $EXPIRY"
else
    # Check alternative common locations
    if [ -f /etc/letsencrypt/live/vseek-server.duckdns.org/fullchain.pem ]; then
        print_success "Let's Encrypt certificate found (hardcoded path)"
    else
        print_error "No SSL certificate found in standard locations"
        print_info "Checked:"
        print_info "  - /etc/letsencrypt/live/$DOMAIN/"
        print_info "  - /etc/letsencrypt/live/vseek-server.duckdns.org/"
        print_info "  - /etc/nginx/ssl/selfsigned.crt"
    fi
fi

# Also check if nginx config references the certificate
if grep -q "ssl_certificate.*$DOMAIN" /etc/nginx/sites-available/vseek 2>/dev/null; then
    print_success "Nginx config references the certificate"
else
    print_warning "Nginx config may not reference the certificate correctly"
fi

print_divider

# ----------------------------------------------------------------------
# Test 7: Port Accessibility from Internet
# ----------------------------------------------------------------------
print_header "Test 7: External Port Check"

print_info "Checking if ports are reachable from internet..."
print_info "This uses external services to test your ports:"

# Install nmap if needed
if ! command -v nc &> /dev/null; then
    sudo apt install netcat -y >/dev/null 2>&1
fi

# Try to check ports using a public service
if command -v nc &> /dev/null; then
    # Simple test using a public port checker service (this is a basic check)
    print_info "Testing port 80 with canyouseeme.org..."
    PORT80_CHECK=$(curl -s "https://portchecker.co/check?port=80&ip=$PUBLIC_IP" 2>/dev/null | grep -o "open\|closed" || echo "unknown")
    
    if [ "$PORT80_CHECK" = "open" ]; then
        print_success "Port 80 appears to be open from internet"
    else
        print_warning "Port 80 may be closed or blocked"
    fi
    
    print_info "Testing port 443 with canyouseeme.org..."
    PORT443_CHECK=$(curl -s "https://portchecker.co/check?port=443&ip=$PUBLIC_IP" 2>/dev/null | grep -o "open\|closed" || echo "unknown")
    
    if [ "$PORT443_CHECK" = "open" ]; then
        print_success "Port 443 appears to be open from internet"
    else
        print_warning "Port 443 may be closed or blocked"
    fi
fi

print_divider

# ----------------------------------------------------------------------
# Test 8: ISP Block Test (Alternative Port)
# ----------------------------------------------------------------------
print_header "Test 8: ISP Block Test (Port 8443)"

print_info "Testing if ISP blocks ports by using alternative port 8443"
print_info "Setting up temporary test on port 8443..."

# Check if port 8443 is already configured
if ! sudo ss -tlnp | grep -q ":8443"; then
    # Add temporary port 8443 to nginx config
    if [ -f /etc/nginx/sites-available/vseek ]; then
        # Check if port 8443 is already in config
        if ! grep -q "listen 8443" /etc/nginx/sites-available/vseek; then
            sudo sed -i '/listen 443 ssl;/a \    listen 8443 ssl;' /etc/nginx/sites-available/vseek
            sudo nginx -t && sudo systemctl reload nginx
            print_success "Temporarily added port 8443 to nginx"
        fi
    fi
fi

if sudo ss -tlnp | grep -q ":8443"; then
    print_success "Port 8443 is listening"
    print_info ""
    print_info "To test if your ISP blocks ports, run this from your phone (cellular data):"
    print_info "  curl -k https://$PUBLIC_IP:8443"
    print_info ""
    print_info "If this works but port 443 doesn't, your ISP is blocking port 443"
else
    print_warning "Could not configure port 8443 for testing"
fi

print_divider

# ----------------------------------------------------------------------
# Summary and Recommendations
# ----------------------------------------------------------------------
print_header "Diagnostic Summary"

echo ""
echo "Based on the tests above, here are common issues and solutions:"
echo ""

# Check for most likely issues
if ! systemctl is-active --quiet nginx; then
    print_error "ISSUE: Nginx is not running"
    print_info "FIX: sudo systemctl start nginx"
fi

if ! sudo ufw status | grep -q "active"; then
    print_warning "ISSUE: Firewall may not be active"
    print_info "FIX: sudo ufw enable"
fi

if [ -n "$DNS_IP" ] && [ "$DNS_IP" != "$PUBLIC_IP" ]; then
    print_warning "ISSUE: DuckDNS IP doesn't match current public IP"
    print_info "FIX: ~/duckdns/duck.sh"
fi

if ! sudo ss -tlnp | grep -q ":443"; then
    print_error "ISSUE: Port 443 is not listening"
    print_info "FIX: Check nginx configuration"
fi

print_divider

echo ""
echo "📋 **Manual Tests to Run from Outside:**"
echo ""
echo "1. From your phone (cellular data, WiFi OFF):"
echo "   curl -v http://$DOMAIN"
echo "   curl -v https://$DOMAIN"
echo "   curl -v http://$PUBLIC_IP"
echo "   curl -v https://$PUBLIC_IP"
echo ""
echo "2. Online port checker:"
echo "   https://canyouseeme.org - Check ports 80 and 443"
echo ""
echo "3. DNS checker:"
echo "   https://dnschecker.org/#A/$DOMAIN"
echo ""

print_info "For more detailed logs:"
print_info "  Nginx:   sudo journalctl -u nginx -f"
print_info "  Certbot: sudo tail -f /var/log/letsencrypt/letsencrypt.log"
echo ""

# ----------------------------------------------------------------------
# Optional: Generate a report file
# ----------------------------------------------------------------------
REPORT_FILE="verify-report-$(date +%Y%m%d-%H%M%S).txt"
print_header "Saving Report"

{
    echo "Verification Report - $(date)"
    echo "================================"
    echo ""
    echo "Local IP: $LOCAL_IP"
    echo "Public IP: $PUBLIC_IP"
    echo "Domain: $DOMAIN"
    echo ""
    echo "Nginx Status:"
    systemctl status nginx --no-pager
    echo ""
    echo "Firewall Status:"
    sudo ufw status verbose
    echo ""
    echo "Listening Ports:"
    sudo ss -tlnp | grep -E ':(80|443)'
    echo ""
    echo "DNS Resolution:"
    dig +short $DOMAIN
    echo ""
    echo "Certificate Info:"
    if [ -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem ]; then
        sudo openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -noout -text | grep -E "Not Before|Not After"
    fi
} > "$REPORT_FILE"

print_success "Report saved to: $REPORT_FILE"
echo ""