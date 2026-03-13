# verification script should check connectivity layer by layer:
# 1. Server services
# 2. Local HTTP
# 3. DNS resolution
# 4. Public IP detection
# 5. Public HTTP connectivity
# 6. Public HTTPS connectivity
# 7. Port reachability

#!/bin/bash

source config/variables.conf

LOCAL_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s ifconfig.me)

echo "=============================="
echo "Server Diagnostics"
echo "=============================="

echo ""
echo "Local IP:  $LOCAL_IP"
echo "Public IP: $PUBLIC_IP"
echo "Domain:    $DOMAIN"

echo ""
echo "------------------------------"
echo "1️⃣ Checking services"
echo "------------------------------"

systemctl is-active nginx && echo "Nginx: PASS" || echo "Nginx: FAIL"
systemctl is-active fail2ban && echo "Fail2Ban: PASS" || echo "Fail2Ban: FAIL"

echo ""
echo "------------------------------"
echo "2️⃣ Testing local HTTP"
echo "------------------------------"

if curl -s http://localhost | grep "Hello World" > /dev/null
then
    echo "Local HTTP: PASS"
else
    echo "Local HTTP: FAIL"
fi

echo ""
echo "------------------------------"
echo "3️⃣ Testing DNS resolution"
echo "------------------------------"

DNS_IP=$(dig +short $DOMAIN | tail -n1)

echo "DNS resolves to: $DNS_IP"

if [[ "$DNS_IP" == "$PUBLIC_IP" ]]
then
    echo "DNS match: PASS"
else
    echo "DNS match: WARNING"
fi

echo ""
echo "------------------------------"
echo "4️⃣ Testing public HTTP"
echo "------------------------------"

if curl -s http://$PUBLIC_IP | grep "Hello World" > /dev/null
then
    echo "Public HTTP (IP): PASS"
else
    echo "Public HTTP (IP): FAIL"
fi

echo ""
echo "------------------------------"
echo "5️⃣ Testing public HTTPS"
echo "------------------------------"

if curl -k -s https://$DOMAIN | grep "Hello World" > /dev/null
then
    echo "Public HTTPS (domain): PASS"
else
    echo "Public HTTPS (domain): FAIL"
fi

echo ""
echo "------------------------------"
echo "6️⃣ Testing port reachability"
echo "------------------------------"

nc -z -w3 $PUBLIC_IP 80 && echo "Port 80 open" || echo "Port 80 closed"
nc -z -w3 $PUBLIC_IP 443 && echo "Port 443 open" || echo "Port 443 closed"

echo ""
echo "------------------------------"
echo "Firewall status"
echo "------------------------------"

sudo ufw status

echo ""
echo "=============================="
echo "Diagnostics complete"
echo "=============================="