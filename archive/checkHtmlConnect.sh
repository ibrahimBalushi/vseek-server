# =========================
# WEBSITE END-TO-END TESTS
# =========================

echo "================================"
echo "Running website connectivity tests"
echo "================================"

SERVER_IP=$(hostname -I | awk '{print $1}')
DOMAIN="$DUCKDNS_DOMAIN.duckdns.org"

echo ""
echo "1️⃣ Checking website file exists"
if [ -f /var/www/html/index.html ]; then
    echo "PASS: index.html exists"
else
    echo "FAIL: index.html missing"
fi

echo ""
echo "2️⃣ Checking nginx service"
if systemctl is-active --quiet nginx; then
    echo "PASS: nginx running"
else
    echo "FAIL: nginx not running"
fi

echo ""
echo "3️⃣ Testing localhost HTTP"
LOCAL_TEST=$(curl -s http://localhost)

if [[ "$LOCAL_TEST" == *"Hello World"* ]]; then
    echo "PASS: localhost HTTP works"
else
    echo "FAIL: localhost HTTP failed"
fi

echo ""
echo "4️⃣ Testing LAN access"
LAN_TEST=$(curl -s http://$SERVER_IP)

if [[ "$LAN_TEST" == *"Hello World"* ]]; then
    echo "PASS: LAN HTTP works ($SERVER_IP)"
else
    echo "FAIL: LAN HTTP failed"
fi

echo ""
echo "5️⃣ Checking DNS resolution"
DNS_IP=$(dig +short $DOMAIN | tail -n1)

echo "DNS resolves to: $DNS_IP"

if [[ "$DNS_IP" == "$(curl -s ifconfig.me)" ]]; then
    echo "PASS: DNS matches public IP"
else
    echo "WARNING: DNS may not match public IP"
fi

echo ""
echo "6️⃣ Testing public HTTP"
PUBLIC_HTTP=$(curl -s http://$DOMAIN)

if [[ "$PUBLIC_HTTP" == *"Hello World"* ]]; then
    echo "PASS: public HTTP works"
else
    echo "FAIL: public HTTP failed (router forwarding?)"
fi

echo ""
echo "7️⃣ Testing HTTPS"
PUBLIC_HTTPS=$(curl -s -k https://$DOMAIN)

if [[ "$PUBLIC_HTTPS" == *"Hello World"* ]]; then
    echo "PASS: HTTPS works"
else
    echo "FAIL: HTTPS failed"
fi

echo ""
echo "8️⃣ Checking ports"
if ss -tuln | grep -q ":80"; then
    echo "PASS: port 80 listening"
else
    echo "FAIL: port 80 closed"
fi

if ss -tuln | grep -q ":443"; then
    echo "PASS: port 443 listening"
else
    echo "FAIL: port 443 closed"
fi

echo ""
echo "================================"
echo "Website test complete"
echo "================================"