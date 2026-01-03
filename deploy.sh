#!/bin/bash

# Simple deployment script for URL shortener

set -e

echo "🚀 Deploying URL Shortener..."

# Check if running on server
if [ ! -f /.dockerenv ] && [ -d ~/url-shortener ]; then
    cd ~/url-shortener
fi

# Stop old containers
echo "Stopping old containers..."
docker compose down 2>/dev/null || true

# Build new image
echo "Building Docker image..."
docker compose build --no-cache

# Start services
echo "Starting services..."
docker compose up -d

# Wait for services
echo "Waiting for services to start..."
sleep 5

# Show status
echo "✅ Deployment complete!"
docker compose ps

echo ""
echo "📝 Useful commands:"
echo "  docker compose logs -f     # View logs"
echo "  docker compose restart     # Restart services"
echo "  docker compose down        # Stop services"
echo ""
echo "🌐 Your site should be available at:"
echo "  https://lify.cc"