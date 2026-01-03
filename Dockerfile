# Simple production Dockerfile
FROM nginx:alpine

# Copy static files
COPY index.html /usr/share/nginx/html/
COPY app.js /usr/share/nginx/html/
COPY logo.svg /usr/share/nginx/html/

# Copy nginx config
COPY nginx-simple.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

# Run nginx
CMD ["nginx", "-g", "daemon off;"]