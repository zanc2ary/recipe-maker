#!/bin/bash

# RecipeAI - Fixed Amazon Linux 2023 Deployment Script
# Resolves package conflicts and dependency issues

set -e

echo "🚀 Starting RecipeAI deployment on Amazon Linux 2023 (Fixed Version)..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root: sudo bash deploy-amazonlinux2023-fixed.sh"
    exit 1
fi

print_status "Updating system packages and resolving conflicts..."

# Fix package conflicts first
print_status "Resolving curl and package conflicts..."
dnf remove -y curl-minimal || true
dnf install -y curl --allowerasing
dnf update -y --skip-broken

print_status "Installing essential packages..."
dnf groupinstall -y "Development Tools" || dnf install -y gcc gcc-c++ make
dnf install -y wget git tar gzip which procps-ng net-tools

print_status "Installing and configuring nginx..."
dnf install -y nginx
systemctl enable nginx

# Install Node.js using a more reliable method
print_status "Installing Node.js 18.x..."
# Download and install Node.js directly from official source
cd /tmp
wget https://nodejs.org/dist/v18.19.0/node-v18.19.0-linux-x64.tar.xz
tar -xf node-v18.19.0-linux-x64.tar.xz
sudo cp -r node-v18.19.0-linux-x64/* /usr/local/
rm -rf node-v18.19.0-linux-x64*

# Add Node.js to PATH
echo 'export PATH=/usr/local/bin:$PATH' >> /etc/profile
source /etc/profile
ln -sf /usr/local/bin/node /usr/bin/node
ln -sf /usr/local/bin/npm /usr/bin/npm

# Verify Node.js installation
print_status "Verifying Node.js installation..."
/usr/local/bin/node --version
/usr/local/bin/npm --version

# Install PM2
print_status "Installing PM2..."
/usr/local/bin/npm install -g pm2

# Create application structure
APP_NAME="recipeai"
APP_DIR="/opt/$APP_NAME"
APP_USER="recipeai"

print_status "Setting up application structure..."
if ! id "$APP_USER" &>/dev/null; then
    useradd -r -s /bin/bash -d $APP_DIR $APP_USER
fi

mkdir -p $APP_DIR
mkdir -p /var/log/$APP_NAME
chown $APP_USER:$APP_USER $APP_DIR
chown $APP_USER:$APP_USER /var/log/$APP_NAME

# Create environment file
print_status "Creating environment configuration..."
cat > $APP_DIR/.env << EOF
NODE_ENV=production
PORT=3000
HOST=0.0.0.0
LAMBDA_API_URL=https://t34tfhi733.execute-api.ap-southeast-2.amazonaws.com/prod/recommend
EOF

chown $APP_USER:$APP_USER $APP_DIR/.env
chmod 600 $APP_DIR/.env

# Configure nginx with a working configuration
print_status "Configuring nginx..."
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
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  _;
        
        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;

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

# Test nginx configuration
nginx -t

# Configure firewall
print_status "Configuring firewall..."
systemctl enable firewalld
systemctl start firewalld

firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload

# Create startup script that works
print_status "Creating application startup script..."
cat > $APP_DIR/start-app.sh << EOF
#!/bin/bash
cd $APP_DIR

export NODE_ENV=production
export PORT=3000
export HOST=0.0.0.0
export PATH=/usr/local/bin:\$PATH

echo "Starting RecipeAI application..."
echo "Node version: \$(node --version)"
echo "Working directory: \$(pwd)"

if [ -f "dist/server/node-build.mjs" ]; then
    echo "Starting from built server..."
    node dist/server/node-build.mjs
elif [ -f "server/node-build.ts" ]; then
    echo "Building and starting server..."
    npm run build
    node dist/server/node-build.mjs
else
    echo "Error: No server files found!"
    ls -la
    exit 1
fi
EOF

chmod +x $APP_DIR/start-app.sh
chown $APP_USER:$APP_USER $APP_DIR/start-app.sh

# Create systemd service
print_status "Creating systemd service..."
cat > /etc/systemd/system/$APP_NAME.service << EOF
[Unit]
Description=RecipeAI Node.js Application
After=network.target

[Service]
Type=simple
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$APP_DIR
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=HOST=0.0.0.0
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=$APP_DIR/start-app.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# Create deployment helper script
print_status "Creating deployment helper..."
cat > $APP_DIR/deploy.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Deploying RecipeAI..."

APP_DIR="/opt/recipeai"
cd $APP_DIR

# Stop existing service
sudo systemctl stop recipeai || true

# Install dependencies and build
echo "Installing dependencies..."
npm install

echo "Building application..."
npm run build

# Set permissions
sudo chown -R recipeai:recipeai $APP_DIR

# Start services
echo "Starting services..."
sudo systemctl start recipeai
sudo systemctl restart nginx

# Wait and check status
sleep 5
sudo systemctl status recipeai --no-pager
sudo systemctl status nginx --no-pager

echo "��� Deployment complete!"

# Show connection info
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "YOUR_EC2_IP")
echo "🌐 Your app: http://$PUBLIC_IP"

# Test local connection
if curl -s http://localhost/api/ping > /dev/null; then
    echo "✅ App is responding locally"
else
    echo "❌ App not responding - check logs:"
    echo "   sudo journalctl -u recipeai -f"
fi
EOF

chmod +x $APP_DIR/deploy.sh

# Create troubleshooting script
cat > $APP_DIR/troubleshoot.sh << 'EOF'
#!/bin/bash

echo "🔍 RecipeAI Troubleshooting..."

echo "=== System Status ==="
echo "Node.js: $(which node) ($(node --version))"
echo "NPM: $(which npm) ($(npm --version))"

echo ""
echo "=== Service Status ==="
sudo systemctl status recipeai --no-pager
sudo systemctl status nginx --no-pager
sudo systemctl status firewalld --no-pager

echo ""
echo "=== Network Status ==="
netstat -tlnp | grep -E ":(80|3000|443) "

echo ""
echo "=== Firewall Status ==="
sudo firewall-cmd --list-all

echo ""
echo "=== Recent Logs ==="
echo "App logs:"
sudo journalctl -u recipeai --lines 10 --no-pager

echo ""
echo "Nginx logs:"
sudo tail -n 10 /var/log/nginx/error.log

echo ""
echo "=== Test Commands ==="
echo "Local test: curl -I http://localhost"
echo "API test: curl -I http://localhost/api/ping"

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "YOUR_EC2_IP")
echo "External test: curl -I http://$PUBLIC_IP"
EOF

chmod +x $APP_DIR/troubleshoot.sh

# Set final permissions
chown -R $APP_USER:$APP_USER $APP_DIR

print_status "✅ Setup completed!"
print_status ""
print_status "📋 Next Steps:"
print_status "1. Copy your built application to $APP_DIR"
print_status "2. Make sure you have package.json and dist/ folder"
print_status "3. Run: sudo $APP_DIR/deploy.sh"
print_status ""
print_status "🔧 Troubleshooting:"
print_status "   sudo $APP_DIR/troubleshoot.sh"
print_status ""
print_status "🌐 Your app will be available at:"
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "YOUR_EC2_PUBLIC_IP")
print_status "   http://$PUBLIC_IP"

print_warning "Don't forget to check AWS Security Group allows HTTP (port 80) traffic!"
