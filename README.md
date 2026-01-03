# 🔗 URL Shortener

A modern, secure, and fast URL shortener with QR code generation, built with vanilla JavaScript and deployed with Docker + Traefik.

## ✨ Features

- 🎨 Modern glass-morphism UI with dark mode
- 📱 Fully responsive design
- 🔗 URL shortening with custom codes
- 📊 QR code generation for each shortened URL
- 📈 Click statistics tracking
- 💾 Local storage for URL history
- 🔒 SSL/TLS with automatic certificate renewal
- 🛡️ DDoS protection and rate limiting
- 🚀 CI/CD with GitHub Actions

## 🚀 Quick Start

### Option 1: Manual Deployment (Recommended for First Time)

1. **Prepare your server:**
```bash
# SSH to your server
ssh user@your-server-ip

# Download and run server initialization (run as root)
curl -O https://raw.githubusercontent.com/yourusername/url-shortener/main/scripts/init-server.sh
sudo bash init-server.sh
```

2. **Deploy from your local machine:**
```bash
# Clone the repository
git clone https://github.com/yourusername/url-shortener.git
cd url-shortener

# Make script executable
chmod +x scripts/manual-deploy.sh

# Run deployment (will prompt for server details)
./scripts/manual-deploy.sh
```

### Option 2: GitHub Actions Deployment

1. **Fork this repository**

2. **Add GitHub Secrets:**
   - Go to Settings → Secrets → Actions
   - Add these secrets:
     - `SERVER_HOST` - Your server IP
     - `SERVER_USER` - SSH username (e.g., deploy)
     - `SERVER_PASSWORD` - SSH password
     - `DOMAIN_NAME` - Your domain (e.g., short.link)
     - `ACME_EMAIL` - Email for SSL certificates
     - `CF_API_EMAIL` - Cloudflare email (optional)
     - `CF_API_KEY` - Cloudflare API key (optional)
     - `TRAEFIK_DASHBOARD_CREDENTIALS` - Basic auth for Traefik

3. **Push to main branch** - Automatically deploys!

## 🛠️ Server Requirements

- Ubuntu 20.04+ or Debian 11+
- Minimum 1GB RAM
- 10GB disk space
- Domain name pointed to server
- Ports 22, 80, 443 accessible

## 📝 Configuration

### Environment Variables

Copy `.env.example` to `.env` and fill in your values:

```bash
DOMAIN=your-domain.com
ACME_EMAIL=admin@your-domain.com
# Optional Cloudflare for SSL
CF_API_EMAIL=your@email.com
CF_API_KEY=your-api-key
```

### Generate Traefik Dashboard Password

```bash
# Install htpasswd
sudo apt-get install apache2-utils

# Generate password (replace 'admin' and 'yourpassword')
echo $(htpasswd -nb admin yourpassword) | sed -e s/\\$/\\$\\$/g
```

## 🔒 Security Features

- **Firewall**: UFW with strict rules (only 22, 80, 443)
- **Rate Limiting**: 100 requests/minute per IP
- **DDoS Protection**: iptables rules
- **SSL/TLS**: A+ rating configuration
- **Security Headers**: CSP, HSTS, X-Frame-Options
- **Fail2ban**: SSH brute force protection

## 📊 Monitoring

### View Logs
```bash
# SSH to server
ssh deploy@your-server

# Application logs
cd ~/url-shortener
docker-compose logs -f url-shortener

# All logs
docker-compose logs -f
```

### Health Check
```bash
curl https://your-domain.com/health
```

### Traefik Dashboard
Access at: `https://traefik-dashboard.your-domain.com`

## 🔧 Maintenance

### Update Application
```bash
# On server
cd ~/url-shortener
git pull
docker-compose build --no-cache
docker-compose up -d
```

### Restart Services
```bash
docker-compose restart
```

### Clean Up
```bash
docker system prune -af
```

## 🏗️ Project Structure

```
url-shortener/
├── index.html           # Main HTML file
├── app.js              # Application logic
├── logo.svg            # Logo
├── Dockerfile          # Docker container config
├── docker-compose.yml  # Service orchestration
├── traefik.yml        # Reverse proxy config
├── nginx.conf         # Web server config
├── scripts/           # Deployment scripts
│   ├── init-server.sh
│   ├── manual-deploy.sh
│   └── setup-firewall.sh
└── .github/
    └── workflows/
        └── deploy.yml  # CI/CD pipeline
```

## 🐛 Troubleshooting

### Container Won't Start
```bash
docker-compose logs url-shortener
docker ps -a
```

### SSL Certificate Issues
```bash
# Check Traefik logs
docker-compose logs traefik | grep -i acme

# Regenerate certificate
rm traefik-data/acme.json
touch traefik-data/acme.json
chmod 600 traefik-data/acme.json
docker-compose restart traefik
```

### High Memory Usage
```bash
docker stats
docker-compose restart
docker system prune -af
```

## 📄 License

MIT License - feel free to use this project for personal or commercial purposes.

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first.

## 🆘 Support

- Check [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment guide
- Open an issue for bugs or feature requests
- Star the repository if you find it useful!

---

Made with ❤️ using vanilla JavaScript and modern web technologies