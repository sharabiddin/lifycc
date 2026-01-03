#!/bin/bash

# Server Initialization Script
# Run this on a fresh Ubuntu/Debian server to prepare it for deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}     Server Initialization for URL Shortener${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
   echo -e "${RED}Please run as root or with sudo${NC}"
   exit 1
fi

# Update system
echo -e "${YELLOW}Updating system packages...${NC}"
apt-get update
apt-get upgrade -y

# Install essential packages
echo -e "${YELLOW}Installing essential packages...${NC}"
apt-get install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    net-tools \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    ufw \
    fail2ban

# Install Docker
echo -e "${YELLOW}Installing Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
    echo -e "${GREEN}✓ Docker installed${NC}"
else
    echo -e "${GREEN}✓ Docker already installed${NC}"
fi

# Install Docker Compose
echo -e "${YELLOW}Installing Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null; then
    apt-get install -y docker-compose-plugin
    echo -e "${GREEN}✓ Docker Compose installed${NC}"
else
    echo -e "${GREEN}✓ Docker Compose already installed${NC}"
fi

# Create a non-root user for deployment (if not exists)
echo -e "${YELLOW}Setting up deployment user...${NC}"
read -p "Enter username for deployment (default: deploy): " DEPLOY_USER
DEPLOY_USER=${DEPLOY_USER:-deploy}

if id "$DEPLOY_USER" &>/dev/null; then
    echo -e "${GREEN}✓ User $DEPLOY_USER already exists${NC}"
else
    adduser --disabled-password --gecos "" $DEPLOY_USER
    usermod -aG sudo $DEPLOY_USER
    usermod -aG docker $DEPLOY_USER
    echo -e "${GREEN}✓ User $DEPLOY_USER created${NC}"
    
    # Set password
    echo -e "${YELLOW}Please set a password for user $DEPLOY_USER:${NC}"
    passwd $DEPLOY_USER
fi

# Configure SSH (optional)
echo -e "${YELLOW}Configuring SSH...${NC}"
read -p "Do you want to configure SSH for better security? (y/n): " CONFIGURE_SSH

if [[ $CONFIGURE_SSH == "y" || $CONFIGURE_SSH == "Y" ]]; then
    # Backup original SSH config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Configure SSH
    cat > /etc/ssh/sshd_config.d/hardening.conf << EOF
# SSH Hardening Configuration
PermitRootLogin no
MaxAuthTries 3
MaxSessions 10
PasswordAuthentication yes
PubkeyAuthentication yes
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowUsers $DEPLOY_USER
EOF
    
    systemctl restart sshd
    echo -e "${GREEN}✓ SSH configured${NC}"
fi

# Setup basic firewall
echo -e "${YELLOW}Setting up firewall...${NC}"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw --force enable
echo -e "${GREEN}✓ Firewall configured${NC}"

# Setup fail2ban
echo -e "${YELLOW}Configuring fail2ban...${NC}"
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF

systemctl restart fail2ban
systemctl enable fail2ban
echo -e "${GREEN}✓ Fail2ban configured${NC}"

# Setup swap (if not exists)
echo -e "${YELLOW}Checking swap...${NC}"
if [ $(swapon -s | wc -l) -eq 1 ]; then
    echo -e "${YELLOW}Creating 2GB swap file...${NC}"
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
    echo -e "${GREEN}✓ Swap configured${NC}"
else
    echo -e "${GREEN}✓ Swap already configured${NC}"
fi

# Set system limits
echo -e "${YELLOW}Configuring system limits...${NC}"
cat >> /etc/security/limits.conf << EOF
* soft nofile 65535
* hard nofile 65535
* soft nproc 32768
* hard nproc 32768
EOF

# Configure sysctl for better performance
cat > /etc/sysctl.d/99-performance.conf << EOF
# Network optimizations
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.ip_local_port_range = 1024 65535

# Security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
EOF

sysctl -p /etc/sysctl.d/99-performance.conf
echo -e "${GREEN}✓ System limits configured${NC}"

# Create application directory
echo -e "${YELLOW}Creating application directory...${NC}"
mkdir -p /home/$DEPLOY_USER/url-shortener
chown -R $DEPLOY_USER:$DEPLOY_USER /home/$DEPLOY_USER/url-shortener
echo -e "${GREEN}✓ Application directory created${NC}"

# Install monitoring tools (optional)
echo -e "${YELLOW}Installing monitoring tools...${NC}"
apt-get install -y htop iotop nethogs

# Clean up
echo -e "${YELLOW}Cleaning up...${NC}"
apt-get autoremove -y
apt-get autoclean

# Display summary
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}       Server Initialization Complete!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${GREEN}Summary:${NC}"
echo "  • System updated"
echo "  • Docker and Docker Compose installed"
echo "  • User '$DEPLOY_USER' created with docker access"
echo "  • Firewall configured (ports 22, 80, 443 open)"
echo "  • Fail2ban configured for SSH protection"
echo "  • Swap file created (2GB)"
echo "  • System limits optimized"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Log in as '$DEPLOY_USER' user"
echo "  2. Clone your repository or copy files"
echo "  3. Run the deployment script"
echo ""
echo -e "${YELLOW}Security recommendations:${NC}"
echo "  • Consider setting up SSH key authentication"
echo "  • Regularly update your system"
echo "  • Monitor logs in /var/log/"
echo "  • Set up backups for important data"
echo ""
echo -e "${GREEN}Server is ready for deployment!${NC}"