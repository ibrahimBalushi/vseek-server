Author: Ibrahim Al Balush (VSeek Founder) Via ChatGPT (https://chatgpt.com/c/69b21d69-6640-832e-b7d2-edd34e974469)

# -----------------------------------------------------------------
Purpose: Ubuntu server bootstrap script that automatically sets up:
Server setup uses packages:
UFW       #security
Fail2ban  #security
Nginx	  #connectivity
DuckDNS   #domain-name hosting
certbot   #HTTPS

# -----------------------------------------------------------------
File structure setup follows:

server-setup/
│
├── install.sh
├── configure.sh
├── verify.sh
│
├── config/
│   └── variables.conf
│
├── nginx/
│   └── vseek.conf
│
└── duckdns/
    └── duck.sh
  
# ----------------------------------------------------------------- 
 
# Follow the steps:
# Download repo to server home directory *after fresh install*:
git clone  server-setup
cd server-setup

# Turn into execution scripts via bash commands:
chmod +x install.sh
chmod +x configure.sh
chmod +x verify.sh

# To confirm it worked:
ls -l

# You should see:
-rwxr-xr-x install.sh
-rwxr-xr-x configure.sh
-rwxr-xr-x verify.sh

# Install all packages:
./install.sh

# Configure packages
./configure.sh

# Verify connectivity
./configure.sh
