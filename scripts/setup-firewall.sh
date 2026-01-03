#!/bin/bash

# Firewall Setup Script for URL Shortener
# This script configures UFW (Uncomplicated Firewall) for production deployment

set -e

echo "🔒 Setting up firewall configuration..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
   echo "Please run as root or with sudo"
   exit 1
fi

# Install UFW if not installed
if ! command -v ufw &> /dev/null; then
    echo "Installing UFW..."
    apt-get update
    apt-get install -y ufw
fi

# Reset UFW to defaults
echo "Resetting UFW to defaults..."
ufw --force reset

# Set default policies
echo "Setting default policies..."
ufw default deny incoming
ufw default allow outgoing
ufw default deny forward

# Allow SSH (rate limited to prevent brute force)
echo "Allowing SSH with rate limiting..."
ufw limit 22/tcp comment 'SSH rate limited'

# Allow HTTP and HTTPS
echo "Allowing HTTP and HTTPS..."
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Allow Docker Swarm ports (if using Swarm mode)
# ufw allow 2377/tcp comment 'Docker Swarm management'
# ufw allow 7946/tcp comment 'Docker Swarm discovery'
# ufw allow 7946/udp comment 'Docker Swarm discovery'
# ufw allow 4789/udp comment 'Docker Swarm overlay'

# Block common attack ports
echo "Blocking common attack ports..."
ufw deny 23/tcp comment 'Telnet'
ufw deny 135/tcp comment 'RPC'
ufw deny 139/tcp comment 'NetBIOS'
ufw deny 445/tcp comment 'SMB'
ufw deny 1433/tcp comment 'MSSQL'
ufw deny 3306/tcp comment 'MySQL'
ufw deny 3389/tcp comment 'RDP'
ufw deny 5432/tcp comment 'PostgreSQL'
ufw deny 5900/tcp comment 'VNC'
ufw deny 6379/tcp comment 'Redis'
ufw deny 8080/tcp comment 'Alternative HTTP'
ufw deny 11211/tcp comment 'Memcached'
ufw deny 27017/tcp comment 'MongoDB'

# Log configuration
echo "Configuring logging..."
ufw logging on
ufw logging medium

# Enable UFW
echo "Enabling firewall..."
ufw --force enable

# Show status
echo "Firewall status:"
ufw status verbose

# Additional iptables rules for DDoS protection
echo "Adding additional DDoS protection rules..."

# Limit connections per IP
iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above 50 -j REJECT --reject-with tcp-reset
iptables -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above 50 -j REJECT --reject-with tcp-reset

# Protect against SYN floods
iptables -N syn_flood
iptables -A INPUT -p tcp --syn -j syn_flood
iptables -A syn_flood -m limit --limit 1/s --limit-burst 3 -j RETURN
iptables -A syn_flood -j DROP

# Drop invalid packets
iptables -A INPUT -m state --state INVALID -j DROP
iptables -A FORWARD -m state --state INVALID -j DROP
iptables -A OUTPUT -m state --state INVALID -j DROP

# Drop packets with suspicious flags
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -p tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP

# Limit ICMP
iptables -A INPUT -p icmp -m limit --limit 1/s --limit-burst 1 -j ACCEPT
iptables -A INPUT -p icmp -j DROP

# Save iptables rules
echo "Saving iptables rules..."
if command -v iptables-save &> /dev/null; then
    iptables-save > /etc/iptables/rules.v4
fi

# Install fail2ban for additional protection
echo "Installing fail2ban..."
apt-get install -y fail2ban

# Configure fail2ban for nginx
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

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
action = iptables-multiport[name=ReqLimit, port="http,https"]
logpath = /var/log/nginx/error.log

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
action = iptables-multiport[name=NoAuthFailures, port="http,https"]
logpath = /var/log/nginx/error.log

[nginx-badbots]
enabled = true
filter = nginx-badbots
action = iptables-multiport[name=BadBots, port="http,https"]
logpath = /var/log/nginx/access.log

[nginx-noscript]
enabled = true
action = iptables-multiport[name=NoScript, port="http,https"]
filter = nginx-noscript
logpath = /var/log/nginx/access.log
EOF

# Restart fail2ban
systemctl restart fail2ban

echo "✅ Firewall configuration complete!"
echo ""
echo "Summary:"
echo "- UFW enabled with strict default deny policy"
echo "- Allowed ports: 22 (SSH rate-limited), 80 (HTTP), 443 (HTTPS)"
echo "- DDoS protection rules added"
echo "- Fail2ban installed and configured"
echo ""
echo "⚠️  Make sure you have SSH access before disconnecting!"