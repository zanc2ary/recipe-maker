#!/bin/bash

# Quick fix for current RecipeAI deployment issue on Amazon Linux 2023
# This addresses the most common issues preventing EC2 access

set -e

echo "🔧 Fixing current RecipeAI deployment on Amazon Linux 2023..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root: sudo bash fix-current-deployment.sh"
    exit 1
fi

echo "=================================="
echo "1. INSTALLING NGINX (if not present)"
echo "=================================="

# Install nginx if not present
if ! command -v nginx &> /dev/null; then
    print_status "Installing nginx..."
    dnf install -y nginx
else
    print_status "Nginx already installed"
fi

echo "=================================="
echo "2. CONFIGURING NGINX"
echo "=================================="

# Create nginx configuration for your app
print_status "Creating nginx configuration..."
cat > /etc/nginx/conf.d/recipeai.conf << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    # Remove any conflicting default server
    
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
        root /usr/share/nginx/html;
        internal;
    }
    
    # Health check
    location /health {
        proxy_pass http://127.0.0.1:3000/api/ping;
    }
}
EOF

# Remove conflicting default configurations
rm -f /etc/nginx/conf.d/default.conf 2>/dev/null || true
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# Test nginx config
print_status "Testing nginx configuration..."
if nginx -t; then
    print_status "Nginx configuration is valid"
else
    print_error "Nginx configuration error. Checking..."
    nginx -t
fi

echo "=================================="
echo "3. CONFIGURING FIREWALL"
echo "=================================="

# Configure firewalld (Amazon Linux 2023 default firewall)
print_status "Configuring firewalld..."
if ! systemctl is-active --quiet firewalld; then
    systemctl start firewalld
    systemctl enable firewalld
fi

# Add firewall rules
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload

print_status "Firewall configured. Open services:"
firewall-cmd --list-services

echo "=================================="
echo "4. FIXING NODE.JS APP BINDING"
echo "=================================="

# Find your app directory
APP_DIR="/home/ec2-user/recipe-maker"
if [ ! -d "$APP_DIR" ]; then
    APP_DIR="/opt/recipeai"
fi
if [ ! -d "$APP_DIR" ]; then
    # Look for the app in common locations
    for dir in /home/ec2-user/* /opt/* /srv/*; do
        if [ -f "$dir/package.json" ] && grep -q "recipeai\|recipe" "$dir/package.json" 2>/dev/null; then
            APP_DIR="$dir"
            break
        fi
    done
fi

print_status "App directory: $APP_DIR"

if [ -d "$APP_DIR" ]; then
    cd "$APP_DIR"
    
    # Check if the built files exist
    if [ -f "dist/server/node-build.mjs" ]; then
        print_status "Built application found"
        
        # Kill any existing node processes
        pkill -f "node.*node-build" || true
        pkill -f "npm.*start" || true
        
        # Create a startup script that binds to all interfaces
        cat > start-server.js << 'EOF'
import path from "path";
import { fileURLToPath } from "url";
import { createServer } from "./dist/server/index.js";
import express from "express";

const app = createServer();
const port = process.env.PORT || 3000;
const host = "0.0.0.0"; // Bind to all interfaces

// In production, serve the built SPA files
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const distPath = path.join(__dirname, "dist/spa");

console.log(`Serving static files from: ${distPath}`);

// Serve static files
app.use(express.static(distPath));

// Handle React Router - serve index.html for all non-API routes
app.get("*", (req, res) => {
  if (req.path.startsWith("/api/") || req.path.startsWith("/health")) {
    return res.status(404).json({ error: "API endpoint not found" });
  }
  res.sendFile(path.join(distPath, "index.html"));
});

app.listen(port, host, () => {
  console.log(`🚀 RecipeAI server running on http://${host}:${port}`);
  console.log(`📱 Frontend: http://${host}:${port}`);
  console.log(`🔧 API: http://${host}:${port}/api`);
});

process.on("SIGTERM", () => {
  console.log("🛑 Received SIGTERM, shutting down gracefully");
  process.exit(0);
});

process.on("SIGINT", () => {
  console.log("🛑 Received SIGINT, shutting down gracefully");
  process.exit(0);
});
EOF
        
        # Start the server
        print_status "Starting RecipeAI server..."
        nohup node start-server.js > app.log 2>&1 &
        sleep 3
        
    else
        print_error "Built application not found. You need to run 'npm run build' first."
        if [ -f "package.json" ]; then
            print_status "Building application..."
            npm install
            npm run build
            
            # Try starting again
            nohup node start-server.js > app.log 2>&1 &
            sleep 3
        fi
    fi
else
    print_error "Could not find application directory. Please ensure your app is uploaded to the EC2 instance."
fi

echo "=================================="
echo "5. STARTING SERVICES"
echo "=================================="

# Start and enable services
print_status "Starting nginx..."
systemctl enable nginx
systemctl restart nginx

echo "=================================="
echo "6. TESTING CONNECTIVITY"
echo "=================================="

# Test local connections
print_status "Testing local connectivity..."

# Test app on port 3000
if curl -s http://localhost:3000/api/ping > /dev/null 2>&1; then
    print_status "✅ App responds on port 3000"
else
    print_error "❌ App not responding on port 3000"
    if [ -f "$APP_DIR/app.log" ]; then
        echo "Last few lines of app log:"
        tail -n 5 "$APP_DIR/app.log"
    fi
fi

# Test nginx on port 80
if curl -s http://localhost:80 > /dev/null 2>&1; then
    print_status "✅ Nginx responds on port 80"
else
    print_error "❌ Nginx not responding on port 80"
    echo "Nginx error log:"
    tail -n 5 /var/log/nginx/error.log 2>/dev/null || echo "No nginx error log found"
fi

echo "=================================="
echo "7. STATUS SUMMARY"
echo "=================================="

echo "Service Status:"
systemctl is-active nginx && print_status "Nginx: Running" || print_error "Nginx: Not running"
systemctl is-active firewalld && print_status "Firewall: Running" || print_error "Firewall: Not running"

echo ""
echo "Process Status:"
if pgrep -f "node.*start-server" > /dev/null; then
    print_status "RecipeAI app: Running (PID: $(pgrep -f "node.*start-server"))"
else
    print_error "RecipeAI app: Not running"
fi

echo ""
echo "Port Status:"
netstat -tlnp | grep ":80 " && print_status "Port 80: Listening" || print_error "Port 80: Not listening"
netstat -tlnp | grep ":3000 " && print_status "Port 3000: Listening" || print_error "Port 3000: Not listening"

echo ""
echo "=================================="
echo "🎯 TEST YOUR APPLICATION"
echo "=================================="

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "YOUR_EC2_PUBLIC_IP")
print_status "Your RecipeAI app should be available at:"
echo "   �� http://$PUBLIC_IP"
echo ""
print_status "Test commands you can run:"
echo "   curl -I http://$PUBLIC_IP"
echo "   curl -I http://$PUBLIC_IP/api/ping"
echo ""
print_warning "If still not working, check AWS Security Group:"
echo "   - Allow HTTP (port 80) from 0.0.0.0/0"
echo "   - Allow SSH (port 22) from your IP"
echo ""
print_status "View logs:"
echo "   sudo tail -f /var/log/nginx/error.log"
echo "   tail -f $APP_DIR/app.log"

echo ""
print_status "Fix completed! 🎉"
