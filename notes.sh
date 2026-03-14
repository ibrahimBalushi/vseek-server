# HTTP server - redirects to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name vseek-server.duckdns.org 74.58.138.81 10.0.0.141;

    # Redirect all HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}


# after change ports i went into
sudo nano /etc/ssh/sshd_config

# HTTPS server
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name vseek-server.duckdns.org 74.58.138.81 10.0.0.141;

    root /var/www/html;
    index index.html;

    ssl_certificate /etc/letsencrypt/live/vseek-server.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/vseek-server.duckdns.org/privkey.pem;
    
    # Include Certbot's recommended SSL parameters
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        try_files $uri $uri/ =404;
    }
}


# Test all possible local access methods
curl -k http://localhost
curl -k https://localhost
curl -k http://10.0.0.141
curl -k https://10.0.0.141
curl -k http://vseek-server.duckdns.org
curl -k https://vseek-server.duckdns.org

+---------------------+       +---------------------+       +---------------------+
|   Internet          |       |   Home Router       |       |   Ubuntu Server     |
|   (Outside World)   |       |   (Helix)           |       |   10.0.0.141        |
|                     |       |                     |       |                     |
| Public IP:          |       | WAN IP:             |       | - Nginx (ports      |
| 74.58.138.81        |<----->| 74.58.138.81 (from  |<----->|   80,443)           |
|                     |       | ISP)                |       | - Certbot (SSL cert |
| DuckDNS:            |       | LAN IP: 10.0.0.1    |       |   for domain)       |
| vseek-server.duckdns|       |                     |       | - Netplan (sets     |
| resolves to         |       | Port Forwarding:    |       |   static IP)        |
| 74.58.138.81        |       | 80,443 -> 10.0.0.141|       |                     |
+---------------------+       +----------^----------+       +----------^----------+
                                         |                              |
                                         | (local network)              |
                                         |                              |
                              +----------v----------+                   |
                              | Local Machine       |                   |
                              | (your PC)           |                   |
                              | IP: 10.0.0.x        |                   |
                              | Browser:            |                   |
                              |  - tries to access  |                   |
                              |    https://vseek-   |                   |
                              |    server.duckdns.org|                  |
                              +---------------------+                   |
                                                                         |
                         +-----------------------------------------------+
                         |
                         v
+--------------------------------------------------------------------------------+
| Flow of Requests:                                                              |
|                                                                                |
| 1. External request (from internet):                                           |
|    User on internet -> hits 74.58.138.81:443 -> Router forwards -> Server     |
|    -> response back through router -> internet user sees Hello World.         |
|                                                                                |
| 2. Internal request (from local machine to domain):                            |
|    Local machine -> DNS resolves domain to 74.58.138.81 -> tries to connect   |
|    to that IP -> router receives request but doesn't loop back -> connection  |
|    fails (NAT hairpin problem).                                                |
|                                                                                |
| 3. Internal request (to local IP):                                            |
|    Local machine -> https://10.0.0.141 -> direct connection to server -> works|
|    but browser shows certificate warning (domain mismatch).                   |
|                                                                                |
| 4. Internal request with hosts file override:                                  |
|    Local machine with hosts entry (10.0.0.141 domain) -> direct connection    |
|    to server -> works with valid certificate (domain matches).                |
+--------------------------------------------------------------------------------+