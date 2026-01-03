# 🚀 URL Shortener - Production Deployment Guide

## Architecture Overview

```
┌─────────────┐      ┌──────────────┐      ┌────────────────┐
│   Internet  │ ───> │   Cloudflare │ ───> │   Your Server  │
└─────────────┘      └──────────────┘      └────────────────┘
                                                     │
                                            ┌────────▼────────┐
                                            │    Firewall     │
                                            │  (UFW/iptables) │
                                            └────────┬────────┘
                                                     │
                                            ┌────────▼────────┐
                                            │     Traefik     │
                                            │  (Reverse Proxy)│
                                            │   SSL/TLS/WAF   │
                                            └────────┬────────┘
                                                     │
                                            ┌────────▼────────┐
                                            │   URL Shortener │
                                            │  (Docker/Nginx) │
                                            └─────────────────┘
```

## Prerequisites

- Ubuntu 20.04+ or Debian 11+ server
- Domain name pointed to your server
- Cloudflare account (for DNS and SSL)
- GitHub account for CI/CD
- Minimum 1GB RAM, 10GB disk space

## 🔧 Initial Server Setup

### 1. Create Deploy User

```bash
# As root
adduser deploy
usermod -aG sudo deploy
su - deploy
```

### 2. Setup SSH Key Authentication

```bash
# On your local machine
ssh-copy-id deploy@your-server-ip

# On server, disable password authentication
sudo nano /etc/ssh/sshd_config
# Set: PasswordAuthentication no
sudo systemctl restart sshd
```

### 3. Install Docker

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker deploy
# Log out and back in for group changes
```

## 🔒 Security Configuration

### 1. Setup Firewall

```bash
# Run the firewall setup script
sudo bash scripts/setup-firewall.sh
```

This configures:
- ✅ UFW with strict deny-by-default policy
- ✅ Only allows ports: 22 (SSH), 80 (HTTP), 443 (HTTPS)
- ✅ Rate limiting on SSH
- ✅ DDoS protection with iptables
- ✅ Fail2ban for intrusion prevention

### 2. Configure Cloudflare

1. Add your domain to Cloudflare
2. Set SSL/TLS mode to "Full (strict)"
3. Enable these features:
   - Always Use HTTPS
   - Auto Minify (JavaScript, CSS, HTML)
   - Brotli compression
   - Browser Cache TTL: 4 hours
   - Security Level: Medium
   - Challenge Passage: 30 minutes

4. Create API token:
   - Go to My Profile → API Tokens
   - Create Token → Edit zone DNS
   - Save the token for GitHub secrets

## 🔑 GitHub Secrets Configuration

Add these secrets to your GitHub repository (Settings → Secrets → Actions):

| Secret Name | Description | Example |
|------------|-------------|---------|
| `DOMAIN_NAME` | Your domain | `example.com` |
| `ACME_EMAIL` | Email for SSL certificates | `admin@example.com` |
| `CF_API_EMAIL` | Cloudflare account email | `you@example.com` |
| `CF_API_KEY` | Cloudflare Global API Key | `abc123...` |
| `SERVER_HOST` | Server IP address | `192.168.1.1` |
| `SERVER_USER` | Deploy user | `deploy` |
| `SERVER_SSH_KEY` | Private SSH key | `-----BEGIN RSA...` |
| `TRAEFIK_DASHBOARD_CREDENTIALS` | Basic auth for Traefik | `admin:$2y$10$...` |

### Generate Traefik Dashboard Credentials:

```bash
# Install htpasswd
sudo apt-get install apache2-utils

# Generate credentials (replace 'admin' and 'your_password')
echo $(htpasswd -nb admin your_password) | sed -e s/\\$/\\$\\$/g
```

## 📦 Deployment

### Manual Deployment

1. SSH to your server:
```bash
ssh deploy@your-server-ip
```

2. Clone the repository:
```bash
git clone https://github.com/yourusername/url-shortener.git
cd url-shortener
```

3. Create `.env` file:
```bash
cp .env.example .env
nano .env
# Fill in all required values
```

4. Run deployment:
```bash
sudo bash scripts/deploy.sh
```

### Automatic Deployment (CI/CD)

Push to main branch triggers automatic deployment:

```bash
git add .
git commit -m "Deploy to production"
git push origin main
```

GitHub Actions will:
1. Run tests and security scans
2. Build Docker image
3. Push to GitHub Container Registry
4. Deploy to your server
5. Run health checks

## 🔍 Monitoring

### View Logs

```bash
# Application logs
docker-compose logs -f url-shortener

# Traefik logs
docker-compose logs -f traefik

# All logs
docker-compose logs -f
```

### Health Checks

```bash
# Local health check
curl http://localhost/health

# External health check
curl https://your-domain.com/health
```

### Traefik Dashboard

Access at: `https://traefik-dashboard.your-domain.com`
(Use credentials from TRAEFIK_DASHBOARD_CREDENTIALS)

## 🛡️ Security Features

### Rate Limiting
- 100 requests/minute per IP
- Burst of 50 requests
- Returns 429 status when exceeded

### Security Headers
- HSTS with preload
- CSP (Content Security Policy)
- X-Frame-Options: SAMEORIGIN
- X-Content-Type-Options: nosniff
- Referrer-Policy: strict-origin-when-cross-origin

### SSL/TLS Configuration
- TLS 1.2+ only
- Strong cipher suites
- OCSP stapling
- Perfect Forward Secrecy

## 🔧 Maintenance

### Update Application

```bash
cd ~/url-shortener
git pull origin main
docker-compose build --no-cache
docker-compose up -d
```

### Backup

```bash
# Backup Docker volumes
docker run --rm -v url-shortener_data:/data -v $(pwd):/backup alpine tar czf /backup/backup-$(date +%Y%m%d).tar.gz /data

# Backup Traefik certificates
tar czf traefik-backup-$(date +%Y%m%d).tar.gz traefik-data/
```

### Restore

```bash
# Restore Docker volumes
docker run --rm -v url-shortener_data:/data -v $(pwd):/backup alpine tar xzf /backup/backup-20240101.tar.gz

# Restore Traefik certificates
tar xzf traefik-backup-20240101.tar.gz
```

### SSL Certificate Renewal

Traefik automatically renews Let's Encrypt certificates. To force renewal:

```bash
# Delete existing certificate
rm traefik-data/acme.json
touch traefik-data/acme.json
chmod 600 traefik-data/acme.json

# Restart Traefik
docker-compose restart traefik
```

## 🚨 Troubleshooting

### Container won't start

```bash
# Check logs
docker-compose logs url-shortener

# Check disk space
df -h

# Check memory
free -m
```

### SSL certificate issues

```bash
# Check Traefik logs
docker-compose logs traefik | grep -i acme

# Verify DNS
nslookup your-domain.com

# Test certificate
curl -vI https://your-domain.com
```

### High CPU/Memory usage

```bash
# Check resource usage
docker stats

# Restart containers
docker-compose restart

# Clean up
docker system prune -af
```

## 📊 Performance Optimization

### 1. Enable Cloudflare Caching

Page Rules:
- `*your-domain.com/*` → Cache Level: Standard

### 2. Optimize Images

```bash
# Install image optimizer
sudo apt-get install jpegoptim optipng

# Optimize before deployment
find . -name "*.jpg" -exec jpegoptim {} \;
find . -name "*.png" -exec optipng {} \;
```

### 3. Monitor Performance

Use tools like:
- Google PageSpeed Insights
- GTmetrix
- WebPageTest
- Lighthouse

## 🆘 Support

### Logs Location
- Application: `/var/lib/docker/containers/*/logs`
- Traefik: `~/url-shortener/traefik-data/logs/`
- System: `/var/log/syslog`

### Common Commands

```bash
# Restart everything
docker-compose down && docker-compose up -d

# View running containers
docker ps

# Enter container shell
docker exec -it url-shortener sh

# Check port usage
sudo netstat -tulpn

# Check firewall status
sudo ufw status verbose

# View fail2ban status
sudo fail2ban-client status
```

## 📝 Production Checklist

Before going live:

- [ ] Domain DNS configured
- [ ] SSL certificate obtained
- [ ] Firewall configured
- [ ] Rate limiting enabled
- [ ] Security headers configured
- [ ] Backups scheduled
- [ ] Monitoring setup
- [ ] Error tracking configured
- [ ] GitHub secrets configured
- [ ] Health checks passing
- [ ] Load testing performed
- [ ] Security scan completed

## 🎯 Performance Targets

- Page Load Time: < 2 seconds
- Time to First Byte: < 200ms
- SSL Labs Score: A+
- Security Headers Score: A+
- Lighthouse Score: > 90

## 📄 License

MIT License - See LICENSE file for details