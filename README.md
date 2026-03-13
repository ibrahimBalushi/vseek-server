<h1 align="center">VSeek Server Setup</h1>

<p align="center">
Automated Ubuntu Server bootstrap for secure web hosting
</p>

<p align="center">
<img src="https://img.shields.io/badge/Ubuntu-22.04-orange" alt="Ubuntu 22.04"/>
<img src="https://img.shields.io/badge/Security-UFW%20%7C%20Fail2Ban-green" alt="Security"/>
<img src="https://img.shields.io/badge/HTTPS-Let's%20Encrypt-blue" alt="HTTPS"/>
<img src="https://img.shields.io/badge/License-MIT-lightgrey" alt="License"/>
</p>

---

## Table of Contents

- [Purpose](#purpose)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Architecture](#architecture)
- [Verification](#verification)
- [Author](#author)

---

## Purpose

VSeek automates the setup of a **home Ubuntu server** with:

- **UFW** – Firewall security  
- **Fail2Ban** – Intrusion protection  
- **Nginx** – Web server / reverse proxy  
- **DuckDNS** – Dynamic DNS  
- **Certbot** – HTTPS certificates  

Designed for **Streamlit apps, personal projects, and secure home hosting**.

---

## Project Structure

```text
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
```
 
### Follow the steps:
### Download repo to server home directory *after fresh install*:
`git clone  server-setup`
`cd server-setup`

### Turn into execution scripts via bash commands:
`chmod +x install.sh`

`chmod +x configure.sh`
`chmod +x verify.sh`

### To confirm it worked:
`ls -l`

### You should see:
`-rwxr-xr-x install.sh`
`-rwxr-xr-x configure.sh`
`-rwxr-xr-x verify.sh`

### Install all packages:
`./install.sh`

### Configure packages
`./configure.sh`

### Verify connectivity
`./configure.sh`
