#!/bin/bash

# Deployment Script for URL Shortener
# This script handles the complete deployment process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DEPLOY_USER=${DEPLOY_USER:-deploy}
APP_DIR=${APP_DIR:-/home/$DEPLOY_USER/url-shortener}

echo -e "${GREEN}🚀 Starting deployment of URL Shortener${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command_exists docker; then
    echo -e "${RED}Docker is not installed. Installing...${NC}"
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker $DEPLOY_USER
fi

if ! command_exists docker-compose; then
    echo -e "${RED}Docker Compose is not installed. Installing...${NC}"
    apt-get update
    apt-get install -y docker-compose-plugin
fi

# Create application directory
echo -e "${YELLOW}Creating application directory...${NC}"
mkdir -p $APP_DIR
cd $APP_DIR

# Set up Docker network
echo -e "${YELLOW}Setting up Docker network...${NC}"
docker network create proxy 2>/dev/null || true

# Check for required environment variables
echo -e "${YELLOW}Checking environment configuration...${NC}"
if [ ! -f .env ]; then
    echo -e "${RED}.env file not found!${NC}"
    echo "Please create .env file with required variables:"
    echo "  DOMAIN, ACME_EMAIL, CF_API_EMAIL, CF_API_KEY, TRAEFIK_DASHBOARD_CREDENTIALS"
    exit 1
fi

# Load environment variables
source .env

# Validate required variables
required_vars=("DOMAIN" "ACME_EMAIL" "CF_API_EMAIL" "CF_API_KEY")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}Required variable $var is not set!${NC}"
        exit 1
    fi
done

# Create necessary directories
echo -e "${YELLOW}Creating necessary directories...${NC}"
mkdir -p traefik-data/logs
touch traefik-data/acme.json
chmod 600 traefik-data/acme.json

# Pull latest images
echo -e "${YELLOW}Pulling latest Docker images...${NC}"
docker-compose pull

# Deploy application
echo -e "${YELLOW}Deploying application...${NC}"
docker-compose up -d --force-recreate

# Wait for services to start
echo -e "${YELLOW}Waiting for services to start...${NC}"
sleep 10

# Health check
echo -e "${YELLOW}Performing health check...${NC}"
if curl -f http://localhost/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Application is healthy!${NC}"
else
    echo -e "${RED}❌ Health check failed!${NC}"
    echo "Checking logs..."
    docker-compose logs --tail=50
    exit 1
fi

# Check Traefik
echo -e "${YELLOW}Checking Traefik status...${NC}"
if docker ps | grep -q traefik; then
    echo -e "${GREEN}✅ Traefik is running!${NC}"
else
    echo -e "${RED}❌ Traefik is not running!${NC}"
    docker-compose logs traefik --tail=50
    exit 1
fi

# Clean up old images
echo -e "${YELLOW}Cleaning up old Docker images...${NC}"
docker system prune -af --volumes

# Show running containers
echo -e "${GREEN}Running containers:${NC}"
docker-compose ps

# Show SSL certificate status
echo -e "${YELLOW}SSL Certificate status:${NC}"
if [ -f traefik-data/acme.json ] && [ -s traefik-data/acme.json ]; then
    echo -e "${GREEN}✅ SSL certificate file exists${NC}"
else
    echo -e "${YELLOW}⏳ SSL certificate pending (this may take a few minutes)${NC}"
fi

echo -e "${GREEN}🎉 Deployment complete!${NC}"
echo ""
echo -e "Access your application at: ${GREEN}https://$DOMAIN${NC}"
echo -e "Traefik dashboard at: ${GREEN}https://traefik-dashboard.$DOMAIN${NC}"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "  docker-compose logs -f          # View logs"
echo "  docker-compose ps               # Show running containers"
echo "  docker-compose restart          # Restart services"
echo "  docker-compose down             # Stop services"