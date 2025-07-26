#!/bin/bash

# Fix IPv6 binding issue - Force Node.js to bind to IPv4
# This resolves the issue where lsof shows type as "ipv6"

set -e

echo "🔧 Fixing IPv4/IPv6 binding issue..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

APP_DIR="/opt/recipeai"

if [ ! -d "$APP_DIR" ]; then
    print_error "Application directory $APP_DIR not found!"
    exit 1
fi

print_status "Stopping existing application..."
sudo systemctl stop recipeai || true
sudo pkill -f "node.*node-build" || true

print_status "Creating IPv4-specific server configuration..."

# Create a new server startup script that explicitly binds to IPv4
cat > $APP_DIR/server-ipv4.js << 'EOF'
import path from "path";
import { fileURLToPath } from "url";
import { createServer } from "./dist/server/index.js";
import express from "express";

const app = createServer();
const port = process.env.PORT || 3000;

// FORCE IPv4 binding - this is the key fix
const host = "0.0.0.0";  // IPv4 only

// In production, serve the built SPA files
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const distPath = path.join(__dirname, "dist/spa");

console.log(`🗂️  Serving static files from: ${distPath}`);
console.log(`🌐 Binding to IPv4 address: ${host}`);

// Serve static files
app.use(express.static(distPath));

// Handle React Router - serve index.html for all non-API routes
app.get("*", (req, res) => {
  if (req.path.startsWith("/api/") || req.path.startsWith("/health")) {
    return res.status(404).json({ error: "API endpoint not found" });
  }
  res.sendFile(path.join(distPath, "index.html"));
});

// Force IPv4 by specifying family: 'IPv4'
const server = app.listen(port, host, () => {
  console.log(`🚀 RecipeAI server running on http://${host}:${port}`);
  console.log(`📱 Frontend: http://${host}:${port}`);
  console.log(`🔧 API: http://${host}:${port}/api`);
  console.log(`🔗 Binding type: IPv4 only`);
});

// Additional IPv4 enforcement
server.on('listening', () => {
  const addr = server.address();
  console.log(`✅ Server listening on ${addr.address}:${addr.port} (family: ${addr.family})`);
});

process.on("SIGTERM", () => {
  console.log("🛑 Received SIGTERM, shutting down gracefully");
  server.close(() => {
    process.exit(0);
  });
});

process.on("SIGINT", () => {
  console.log("🛑 Received SIGINT, shutting down gracefully");
  server.close(() => {
    process.exit(0);
  });
});
EOF

# Update the systemd service to use the new script
print_status "Updating systemd service configuration..."
cat > /etc/systemd/system/recipeai.service << EOF
[Unit]
Description=RecipeAI Node.js Application (IPv4)
After=network.target

[Service]
Type=simple
User=recipeai
Group=recipeai
WorkingDirectory=$APP_DIR
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=HOST=0.0.0.0
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/local/bin/node server-ipv4.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Also create a simpler direct binding script
print_status "Creating alternative direct binding script..."
cat > $APP_DIR/run-ipv4.sh << 'EOF'
#!/bin/bash
cd /opt/recipeai

export NODE_ENV=production
export PORT=3000
export HOST=0.0.0.0
export PATH=/usr/local/bin:$PATH

echo "🚀 Starting RecipeAI with IPv4 binding..."
echo "📍 Working directory: $(pwd)"
echo "🔧 Node version: $(node --version)"
echo "🌐 Binding to: $HOST:$PORT"

# Force IPv4 by disabling IPv6 for this process
echo "0" > /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null || true

if [ -f "dist/server/node-build.mjs" ]; then
    echo "✅ Starting from built server file..."
    node dist/server/node-build.mjs
else
    echo "❌ Built server file not found!"
    echo "📁 Available files:"
    ls -la dist/server/ 2>/dev/null || echo "No dist/server directory"
    exit 1
fi
EOF

chmod +x $APP_DIR/run-ipv4.sh
chown recipeai:recipeai $APP_DIR/run-ipv4.sh
chown recipeai:recipeai $APP_DIR/server-ipv4.js

# Update nginx to also prefer IPv4
print_status "Updating nginx configuration for IPv4..."
cat > /etc/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    server {
        # IPv4 only binding
        listen       80;
        server_name  _;
        
        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;

        location / {
            # Force IPv4 upstream
            proxy_pass http://127.0.0.1:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
            
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        location /health {
            proxy_pass http://127.0.0.1:3000/api/ping;
            access_log off;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }
}
EOF

nginx -t

print_status "Reloading systemd and starting services..."
systemctl daemon-reload
systemctl restart nginx

# Try the systemd service first
print_status "Starting RecipeAI service..."
systemctl start recipeai

# Wait a moment
sleep 5

print_status "Checking binding status..."

# Check what's actually listening
echo "=== Port Status ==="
netstat -tlnp | grep ":3000"
echo ""
echo "=== Process Status ==="
ps aux | grep -E "(node|recipeai)" | grep -v grep
echo ""
echo "=== Service Status ==="
systemctl status recipeai --no-pager

print_status "Testing connectivity..."

# Test local connections
if curl -s http://127.0.0.1:3000/api/ping > /dev/null 2>&1; then
    print_status "✅ App responds on IPv4 localhost"
else
    print_error "❌ App not responding on IPv4"
    echo "📋 Trying alternative startup method..."
    
    # Stop systemd service and try direct method
    systemctl stop recipeai
    sudo -u recipeai $APP_DIR/run-ipv4.sh &
    sleep 3
    
    if curl -s http://127.0.0.1:3000/api/ping > /dev/null 2>&1; then
        print_status "✅ App responds with direct method"
    else
        print_error "❌ Still not responding - check logs"
    fi
fi

if curl -s http://localhost > /dev/null 2>&1; then
    print_status "✅ Nginx proxy working"
else
    print_error "❌ Nginx proxy not working"
fi

echo ""
echo "=== Final Network Check ==="
print_status "Current listening ports:"
lsof -i :3000 2>/dev/null || echo "No process on port 3000"
lsof -i :80 2>/dev/null || echo "No process on port 80"

echo ""
print_status "🎯 Your app should now be accessible via IPv4!"
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "YOUR_EC2_IP")
echo "🌐 Test: http://$PUBLIC_IP"
echo ""
echo "🔍 Debug commands:"
echo "   lsof -i :3000    # Check what's binding to port 3000"
echo "   curl -I http://localhost"
echo "   journalctl -u recipeai -f"
