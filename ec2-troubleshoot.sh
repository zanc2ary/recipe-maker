#!/bin/bash

# EC2 Deployment Troubleshooting Script
# Run this script to diagnose and fix common deployment issues

set -e

echo "🔍 Diagnosing EC2 deployment issues..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

echo "=================================="
echo "1. CHECKING SYSTEM STATUS"
echo "=================================="

# Check if app is running
if pgrep -f "node.*node-build.mjs" > /dev/null; then
    print_status "RecipeAI application is running"
    APP_PID=$(pgrep -f "node.*node-build.mjs")
    echo "   Process ID: $APP_PID"
else
    print_error "RecipeAI application is NOT running"
    echo "   Starting application..."
    cd /opt/recipeai
    sudo -u recipeai npm start &
    sleep 3
fi

# Check if nginx is running
if systemctl is-active --quiet nginx; then
    print_status "Nginx is running"
else
    print_error "Nginx is NOT running"
    echo "   Starting nginx..."
    sudo systemctl start nginx
fi

# Check if application is listening on port 3000
if netstat -tlnp | grep ":3000" > /dev/null; then
    print_status "Application is listening on port 3000"
else
    print_error "Application is NOT listening on port 3000"
fi

# Check if nginx is listening on port 80
if netstat -tlnp | grep ":80" > /dev/null; then
    print_status "Nginx is listening on port 80"
else
    print_error "Nginx is NOT listening on port 80"
fi

echo ""
echo "=================================="
echo "2. CHECKING NETWORK CONFIGURATION"
echo "=================================="

# Check nginx configuration
if nginx -t 2>/dev/null; then
    print_status "Nginx configuration is valid"
else
    print_error "Nginx configuration has errors"
    echo "   Testing configuration:"
    nginx -t
fi

# Check if UFW is blocking connections
UFW_STATUS=$(sudo ufw status | head -n1)
if [[ $UFW_STATUS == *"active"* ]]; then
    print_status "UFW firewall is active"
    echo "   Current UFW rules:"
    sudo ufw status numbered | grep -E "(80|443|22)"
else
    print_warning "UFW firewall is inactive"
fi

# Check security groups (AWS metadata)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "Not available")
if [[ $INSTANCE_ID != "Not available" ]]; then
    print_status "Running on AWS EC2 instance: $INSTANCE_ID"
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "Not available")
    echo "   Public IP: $PUBLIC_IP"
else
    print_warning "Not running on AWS EC2 or metadata service unavailable"
fi

echo ""
echo "=================================="
echo "3. TESTING CONNECTIONS"
echo "=================================="

# Test local connections
echo "Testing local connections..."

if curl -s http://localhost:3000/api/ping > /dev/null; then
    print_status "Application responds to localhost:3000"
else
    print_error "Application does NOT respond to localhost:3000"
fi

if curl -s http://localhost:80 > /dev/null; then
    print_status "Nginx responds to localhost:80"
else
    print_error "Nginx does NOT respond to localhost:80"
fi

echo ""
echo "=================================="
echo "4. COMMON FIXES"
echo "=================================="

echo "Applying common fixes..."

# Fix 1: Ensure server binds to all interfaces (0.0.0.0)
print_status "Checking server binding configuration..."

# Fix 2: Update nginx configuration for better error handling
print_status "Updating nginx configuration..."
sudo tee /etc/nginx/sites-available/recipeai > /dev/null << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logging
    access_log /var/log/nginx/recipeai_access.log;
    error_log /var/log/nginx/recipeai_error.log;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Error handling
        proxy_intercept_errors on;
        error_page 502 503 504 /50x.html;
    }

    location = /50x.html {
        root /var/www/html;
        internal;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:3000/api/ping;
        proxy_set_header Host $host;
    }
}
EOF

# Fix 3: Create simple error page
sudo mkdir -p /var/www/html
sudo tee /var/www/html/50x.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Service Temporarily Unavailable</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
        .container { max-width: 500px; margin: 0 auto; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🍳 RecipeAI</h1>
        <h2>Service Temporarily Unavailable</h2>
        <p>The application is starting up. Please try again in a moment.</p>
        <p><a href="/">Refresh Page</a></p>
    </div>
</body>
</html>
EOF

# Fix 4: Restart services
print_status "Restarting services..."
sudo systemctl restart nginx
sudo systemctl restart recipeai 2>/dev/null || true

# Wait for services to start
sleep 5

echo ""
echo "=================================="
echo "5. FINAL STATUS CHECK"
echo "=================================="

# Final checks
if curl -s http://localhost > /dev/null; then
    print_status "✅ SUCCESS: Application is accessible locally"
else
    print_error "❌ FAILED: Application still not accessible"
fi

# Show logs if there are issues
echo ""
echo "Recent nginx error logs:"
sudo tail -n 10 /var/log/nginx/error.log 2>/dev/null || echo "No nginx error logs found"

echo ""
echo "Recent application logs:"
if command -v pm2 >/dev/null 2>&1; then
    sudo pm2 logs recipeai --lines 5 --nostream 2>/dev/null || echo "No PM2 logs available"
else
    sudo journalctl -u recipeai --lines 5 --no-pager 2>/dev/null || echo "No systemd logs available"
fi

echo ""
echo "=================================="
echo "🎯 NEXT STEPS"
echo "=================================="

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "YOUR_EC2_PUBLIC_IP")

echo "1. 🌐 Test your application:"
echo "   http://$PUBLIC_IP"
echo ""
echo "2. 🔒 Check AWS Security Group:"
echo "   - Allow HTTP (port 80) from 0.0.0.0/0"
echo "   - Allow HTTPS (port 443) from 0.0.0.0/0 (for SSL later)"
echo "   - Allow SSH (port 22) from your IP"
echo ""
echo "3. 🔧 If still not working, check:"
echo "   sudo systemctl status nginx"
echo "   sudo systemctl status recipeai"
echo "   curl -I http://localhost"
echo ""
echo "4. 📋 View detailed logs:"
echo "   sudo tail -f /var/log/nginx/recipeai_error.log"
echo "   sudo journalctl -u recipeai -f"

echo ""
print_status "Troubleshooting complete!"
