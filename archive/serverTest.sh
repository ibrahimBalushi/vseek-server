# =========================
# SELF-CHECK
# =========================
echo "Running self-checks..."

echo "--------------------------------"
# 1️⃣ UFW
echo -n "UFW status: "
if sudo ufw status | grep -q "Status: active"; then
    echo "PASS"
else
    echo "FAIL"
fi

# 2️⃣ Fail2Ban
echo -n "Fail2Ban SSH jail: "
if sudo fail2ban-client status sshd >/dev/null 2>&1; then
    echo "PASS"
else
    echo "FAIL"
fi

# 3️⃣ Nginx
echo -n "Nginx process: "
if pgrep nginx >/dev/null; then
    echo "PASS"
else
    echo "FAIL"
fi

echo -n "Nginx configuration syntax: "
if sudo nginx -t >/dev/null 2>&1; then
    echo "PASS"
else
    echo "FAIL"
fi

echo -n "Nginx serving Hello World (HTTP): "
HTTP_TEST=$(curl -s http://localhost)
if [[ "$HTTP_TEST" == *"Hello World"* ]]; then
    echo "PASS"
else
    echo "FAIL"
fi

# 4️⃣ DuckDNS updater script
echo -n "DuckDNS script exists: "
if [[ -f ~/duckdns/duck.sh ]]; then
    echo "PASS"
else
    echo "FAIL"
fi

# 5️⃣ DuckDNS cron
echo -n "DuckDNS cron job: "
if crontab -l | grep -q "duck.sh"; then
    echo "PASS"
else
    echo "FAIL"
fi

# 6️⃣ HTTPS certificate
echo -n "HTTPS certificate: "
if [[ -f /etc/letsencrypt/live/$DUCKDNS_DOMAIN.duckdns.org/fullchain.pem ]]; then
    echo "PASS"
else
    echo "FAIL"
fi

# 7️⃣ Test website via DuckDNS
echo -n "Test website via DuckDNS: "
REMOTE_TEST=$(curl -s -k https://$DUCKDNS_DOMAIN.duckdns.org)
if [[ "$REMOTE_TEST" == *"Hello World"* ]]; then
    echo "PASS"
else
    echo "FAIL (might need router port-forwarding or external test)"
fi

echo "--------------------------------"
echo "Self-check complete."


