#!/bin/bash

# Manual Deployment Script with Password Authentication
# This script deploys the URL shortener to your server using password authentication

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}   URL Shortener - Manual Deployment Script${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if sshpass is installed
if ! command -v sshpass &> /dev/null; then
    echo -e "${YELLOW}Installing sshpass for password authentication...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install hudochenkov/sshpass/sshpass
        else
            echo -e "${RED}Please install Homebrew first: https://brew.sh${NC}"
            exit 1
        fi
    else
        # Linux
        sudo apt-get update && sudo apt-get install -y sshpass
    fi
fi

# Prompt for server details
echo -e "${YELLOW}Please enter your server details:${NC}"
read -p "Server IP/Host: " SERVER_HOST
read -p "Username: " SERVER_USER
read -s -p "Password: " SERVER_PASSWORD
echo ""
read -p "Domain name (e.g., example.com): " DOMAIN_NAME

# Optional: Cloudflare details for SSL
echo ""
echo -e "${YELLOW}Enter Cloudflare details for SSL (optional, press Enter to skip):${NC}"
read -p "Cloudflare email: " CF_API_EMAIL
read -p "Cloudflare API key: " CF_API_KEY
read -p "ACME email for Let's Encrypt: " ACME_EMAIL

# Create deployment archive
echo ""
echo -e "${YELLOW}Creating deployment archive...${NC}"
tar -czf deployment.tar.gz \
    index.html \
    app.js \
    logo.svg \
    Dockerfile \
    nginx.conf \
    default.conf \
    docker-compose.yml \
    traefik.yml \
    traefik-data/ \
    scripts/ 2>/dev/null || true

# Function to run SSH commands with password
run_ssh() {
    SSHPASS="$SERVER_PASSWORD" sshpass -e ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_HOST" "$1"
}

# Function to copy files with password
copy_scp() {
    SSHPASS="$SERVER_PASSWORD" sshpass -e scp -o StrictHostKeyChecking=no "$1" "$SERVER_USER@$SERVER_HOST:$2"
}

echo -e "${YELLOW}Connecting to server...${NC}"

# Test connection
if run_ssh "echo 'Connection successful'" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Connected to server${NC}"
else
    echo -e "${RED}✗ Failed to connect to server. Please check your credentials.${NC}"
    exit 1
fi

# Check if Docker is installed
echo -e "${YELLOW}Checking Docker installation...${NC}"
if run_ssh "command -v docker" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Docker is installed${NC}"
else
    echo -e "${YELLOW}Docker not found. Installing Docker...${NC}"
    run_ssh "curl -fsSL https://get.docker.com | sh"
    run_ssh "sudo usermod -aG docker $SERVER_USER"
    echo -e "${GREEN}✓ Docker installed${NC}"
    echo -e "${YELLOW}Note: You may need to log out and back in for group changes to take effect${NC}"
fi

# Check if docker-compose is installed
echo -e "${YELLOW}Checking Docker Compose installation...${NC}"
if run_ssh "command -v docker-compose || docker compose version" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Docker Compose is installed${NC}"
else
    echo -e "${YELLOW}Installing Docker Compose...${NC}"
    run_ssh "sudo apt-get update && sudo apt-get install -y docker-compose-plugin"
    echo -e "${GREEN}✓ Docker Compose installed${NC}"
fi

# Create application directory
echo -e "${YELLOW}Creating application directory...${NC}"
run_ssh "mkdir -p ~/url-shortener"

# Copy deployment archive
echo -e "${YELLOW}Copying files to server...${NC}"
copy_scp "deployment.tar.gz" "~/url-shortener/"

# Extract files on server
echo -e "${YELLOW}Extracting files...${NC}"
run_ssh "cd ~/url-shortener && tar -xzf deployment.tar.gz && rm deployment.tar.gz"

# Create .env file
echo -e "${YELLOW}Creating environment configuration...${NC}"
ENV_CONTENT="DOMAIN=$DOMAIN_NAME"

if [ ! -z "$CF_API_EMAIL" ]; then
    ENV_CONTENT="$ENV_CONTENT
CF_API_EMAIL=$CF_API_EMAIL
CF_API_KEY=$CF_API_KEY
ACME_EMAIL=${ACME_EMAIL:-admin@$DOMAIN_NAME}"
else
    ENV_CONTENT="$ENV_CONTENT
ACME_EMAIL=${ACME_EMAIL:-admin@$DOMAIN_NAME}"
fi

# Generate Traefik dashboard credentials
TRAEFIK_USER="admin"
TRAEFIK_PASS=$(openssl rand -base64 12)
if command -v htpasswd &> /dev/null; then
    TRAEFIK_CREDS=$(htpasswd -nb $TRAEFIK_USER $TRAEFIK_PASS | sed -e s/\\$/\\$\\$/g)
else
    # Fallback: use a default hash (admin:admin)
    TRAEFIK_CREDS='admin:$$2y$$10$$EIHMqRmtqKrqVmezxXmc2uSVXMhLCz2n85L5Yt1HSY.e6T7tiNHbS'
    TRAEFIK_PASS="admin"
fi

ENV_CONTENT="$ENV_CONTENT
TRAEFIK_DASHBOARD_CREDENTIALS=$TRAEFIK_CREDS"

run_ssh "cat > ~/url-shortener/.env << 'EOF'
$ENV_CONTENT
EOF"

# Build Docker image on server
echo -e "${YELLOW}Building Docker image on server...${NC}"
run_ssh "cd ~/url-shortener && docker build -t url-shortener:latest ."
echo -e "${GREEN}✓ Docker image built${NC}"

# Create Docker network
echo -e "${YELLOW}Creating Docker network...${NC}"
run_ssh "docker network create proxy 2>/dev/null || true"

# Set up Traefik data
echo -e "${YELLOW}Setting up Traefik...${NC}"
run_ssh "cd ~/url-shortener && mkdir -p traefik-data/logs && touch traefik-data/acme.json && chmod 600 traefik-data/acme.json"

# Deploy with Docker Compose
echo -e "${YELLOW}Starting services...${NC}"
run_ssh "cd ~/url-shortener && docker-compose down 2>/dev/null || true"
run_ssh "cd ~/url-shortener && docker-compose up -d"

# Wait for services
echo -e "${YELLOW}Waiting for services to start...${NC}"
sleep 15

# Check deployment status
echo -e "${YELLOW}Checking deployment status...${NC}"
CONTAINER_STATUS=$(run_ssh "cd ~/url-shortener && docker-compose ps")
echo "$CONTAINER_STATUS"

# Health check
echo -e "${YELLOW}Running health check...${NC}"
if run_ssh "curl -f http://localhost/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Application is healthy${NC}"
else
    echo -e "${YELLOW}⚠ Health check failed (this might be normal if SSL is still being configured)${NC}"
fi

# Clean up local files
rm -f deployment.tar.gz

# Display summary
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}       Deployment Complete!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${GREEN}Application URL:${NC} https://$DOMAIN_NAME"
echo -e "${GREEN}Traefik Dashboard:${NC} https://traefik-dashboard.$DOMAIN_NAME"
echo -e "${GREEN}Dashboard Username:${NC} $TRAEFIK_USER"
echo -e "${GREEN}Dashboard Password:${NC} $TRAEFIK_PASS"
echo ""
echo -e "${YELLOW}Useful commands on server:${NC}"
echo "  cd ~/url-shortener"
echo "  docker-compose logs -f        # View logs"
echo "  docker-compose ps             # Show containers"
echo "  docker-compose restart        # Restart services"
echo "  docker-compose down           # Stop services"
echo ""
echo -e "${YELLOW}Note:${NC} SSL certificate may take a few minutes to generate."
echo "If you're using Cloudflare, make sure your domain is proxied through Cloudflare."