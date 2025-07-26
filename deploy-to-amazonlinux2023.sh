#!/bin/bash

# RecipeAI Web App - Amazon Linux 2023 EC2 Deployment Script
# This script sets up a complete production environment on Amazon Linux 2023

set -e  # Exit on any error

echo "🚀 Starting RecipeAI deployment on Amazon Linux 2023..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="recipeai"
APP_DIR="/opt/$APP_NAME"
APP_USER="recipeai"
DOMAIN="your-domain.com"  # Replace with your domain
PORT=3000

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
    print_error "Please run this script as root (use sudo)"
    exit 1
fi

print_status "Updating system packages..."
dnf update -y

print_status "Installing required packages..."
dnf install -y curl wget git nginx firewalld gcc-c++ make

# Install Node.js 18.x (Amazon Linux 2023 compatible)
print_status "Installing Node.js 18.x..."
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
dnf install -y nodejs

# Verify installations
print_status "Verifying installations..."
node_version=$(node --version)
npm_version=$(npm --version)
print_status "Node.js version: $node_version"
print_status "npm version: $npm_version"

# Create application user
print_status "Creating application user: $APP_USER"
if ! id "$APP_USER" &>/dev/null; then
    useradd -r -s /bin/bash -d $APP_DIR $APP_USER
fi

# Create application directory
print_status "Setting up application directory: $APP_DIR"
mkdir -p $APP_DIR
chown $APP_USER:$APP_USER $APP_DIR

# Install PM2 globally
print_status "Installing PM2 process manager..."
npm install -g pm2

print_warning "APPLICATION CODE SETUP REQUIRED:"
print_warning "You need to copy your application files to $APP_DIR"
print_warning "This includes: package.json, client/, server/, shared/, dist/, etc."

# Create environment file template
print_status "Creating environment configuration..."
cat > $APP_DIR/.env << EOF
# Production Environment Variables
NODE_ENV=production
PORT=$PORT
HOST=0.0.0.0

# Your Lambda API (already configured)
LAMBDA_API_URL=https://t34tfhi733.execute-api.ap-southeast-2.amazonaws.com/prod/recommend

# Add any additional environment variables here
EOF

chown $APP_USER:$APP_USER $APP_DIR/.env
chmod 600 $APP_DIR/.env

print_warning "IMPORTANT: Edit $APP_DIR/.env with your actual environment variables!"

# Create PM2 ecosystem file
print_status "Creating PM2 configuration..."
cat > $APP_DIR/ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: '$APP_NAME',
    script: './dist/server/node-build.mjs',
    cwd: '$APP_DIR',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'development',
      PORT: $PORT,
      HOST: '0.0.0.0'
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: $PORT,
      HOST: '0.0.0.0'
    },
    error_file: '/var/log/$APP_NAME/error.log',
    out_file: '/var/log/$APP_NAME/out.log',
    log_file: '/var/log/$APP_NAME/combined.log',
    time: true,
    watch: false,
    max_memory_restart: '1G',
    restart_delay: 5000
  }]
};
EOF

# Create log directory
mkdir -p /var/log/$APP_NAME
chown $APP_USER:$APP_USER /var/log/$APP_NAME

# Update server to bind to all interfaces
print_status "Creating server configuration to bind to all interfaces..."
cat > $APP_DIR/server-start.js << EOF
// Updated server start script for production
const { createServer } = require('./dist/server/index.js');
const path = require('path');
const express = require('express');

const app = createServer();
const port = process.env.PORT || $PORT;
const host = process.env.HOST || '0.0.0.0';

// Serve static files in production
if (process.env.NODE_ENV === 'production') {
  const distPath = path.join(__dirname, 'dist/spa');
  app.use(express.static(distPath));
  
  // Handle React Router
  app.get('*', (req, res) => {
    if (req.path.startsWith('/api/') || req.path.startsWith('/health')) {
      return res.status(404).json({ error: 'API endpoint not found' });
    }
    res.sendFile(path.join(distPath, 'index.html'));
  });
}

app.listen(port, host, () => {
  console.log(\`🚀 RecipeAI server running on http://\${host}:\${port}\`);
  console.log(\`📱 Frontend: http://\${host}:\${port}\`);
  console.log(\`🔧 API: http://\${host}:\${port}/api\`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('🛑 Received SIGTERM, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('🛑 Received SIGINT, shutting down gracefully');
  process.exit(0);
});
EOF

# Configure Nginx
print_status "Configuring Nginx reverse proxy..."
cat > /etc/nginx/conf.d/$APP_NAME.conf << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    # Remove default server block
    server_tokens off;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Logging
    access_log /var/log/nginx/$APP_NAME-access.log;
    error_log /var/log/nginx/$APP_NAME-error.log;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/javascript;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Increase proxy timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Handle errors gracefully
        proxy_intercept_errors on;
        error_page 502 503 504 /50x.html;
    }
    
    location = /50x.html {
        root /usr/share/nginx/html;
        internal;
    }

    # Health check
    location /health {
        proxy_pass http://127.0.0.1:$PORT/api/ping;
        proxy_set_header Host \$host;
        access_log off;
    }

    # Static files caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        proxy_pass http://127.0.0.1:$PORT;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Remove default nginx configuration
rm -f /etc/nginx/conf.d/default.conf
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# Test nginx configuration
print_status "Testing Nginx configuration..."
nginx -t

# Configure firewall (firewalld for Amazon Linux 2023)
print_status "Configuring firewalld..."
systemctl enable firewalld
systemctl start firewalld

# Configure firewall rules
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

print_status "Firewall rules applied:"
firewall-cmd --list-services

# Enable and start services
print_status "Enabling services..."
systemctl enable nginx
systemctl enable firewalld

# Create systemd service for the app
print_status "Setting up systemd service..."
cat > /etc/systemd/system/$APP_NAME.service << EOF
[Unit]
Description=$APP_NAME Node.js Application
After=network.target

[Service]
Type=simple
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$APP_DIR
Environment=NODE_ENV=production
Environment=PORT=$PORT
Environment=HOST=0.0.0.0
ExecStart=/usr/bin/node dist/server/node-build.mjs
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=$APP_NAME

[Install]
WantedBy=multi-user.target
EOF

# Create application build script
print_status "Creating build script..."
cat > $APP_DIR/build-and-deploy.sh << EOF
#!/bin/bash
set -e

echo "Building $APP_NAME application..."

# Navigate to app directory
cd $APP_DIR

# Install dependencies
echo "Installing dependencies..."
npm ci --production=false

# Build the application
echo "Building application..."
npm run build

# Install production dependencies only
echo "Installing production dependencies..."
rm -rf node_modules
npm ci --production

echo "Build completed successfully!"
EOF

chmod +x $APP_DIR/build-and-deploy.sh
chown $APP_USER:$APP_USER $APP_DIR/build-and-deploy.sh

# Create simple health check page
mkdir -p /usr/share/nginx/html
cat > /usr/share/nginx/html/50x.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>🍳 RecipeAI - Starting Up</title>
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif; 
            text-align: center; 
            margin-top: 50px; 
            background: linear-gradient(to bottom right, #fff7ed, #fef3c7, #fef9c3);
            min-height: 100vh;
            padding: 20px;
        }
        .container { 
            max-width: 500px; 
            margin: 0 auto; 
            background: white;
            padding: 40px;
            border-radius: 12px;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        }
        .chef-icon { font-size: 48px; margin-bottom: 20px; }
        h1 { color: #d97706; margin-bottom: 10px; }
        h2 { color: #374151; margin-bottom: 20px; }
        p { color: #6b7280; line-height: 1.6; }
        .btn { 
            display: inline-block; 
            background: #d97706; 
            color: white; 
            padding: 12px 24px; 
            text-decoration: none; 
            border-radius: 6px; 
            margin-top: 20px;
        }
        .btn:hover { background: #b45309; }
    </style>
</head>
<body>
    <div class="container">
        <div class="chef-icon">👨‍🍳</div>
        <h1>RecipeAI</h1>
        <h2>Service Starting Up</h2>
        <p>The recipe builder is getting ready! Please wait a moment while we prepare everything for you.</p>
        <a href="/" class="btn">Try Again</a>
    </div>
    <script>
        // Auto-refresh after 10 seconds
        setTimeout(() => window.location.reload(), 10000);
    </script>
</body>
</html>
EOF

# Set ownership
chown -R $APP_USER:$APP_USER $APP_DIR

# Create deployment completion script
print_status "Creating deployment completion script..."
cat > $APP_DIR/complete-deployment.sh << EOF
#!/bin/bash
# Run this script after uploading your application code

set -e

echo "Completing $APP_NAME deployment..."

# Build the application
sudo -u $APP_USER $APP_DIR/build-and-deploy.sh

# Reload systemd and start services
systemctl daemon-reload
systemctl enable $APP_NAME
systemctl start $APP_NAME
systemctl restart nginx

# Wait a moment for services to start
sleep 5

# Check status
systemctl status $APP_NAME --no-pager
systemctl status nginx --no-pager

echo ""
echo "🎉 Deployment completed!"
echo ""
echo "🌐 Your app should be available at:"
PUBLIC_IP=\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "YOUR_EC2_PUBLIC_IP")
echo "   http://\$PUBLIC_IP"
echo ""
echo "📊 Monitoring commands:"
echo "   sudo systemctl status $APP_NAME"
echo "   sudo journalctl -u $APP_NAME -f"
echo "   sudo tail -f /var/log/nginx/$APP_NAME-error.log"
EOF

chmod +x $APP_DIR/complete-deployment.sh

# Create quick fix script for immediate testing
print_status "Creating quick fix script..."
cat > $APP_DIR/quick-fix.sh << EOF
#!/bin/bash
# Quick fix script to get the app running immediately

set -e

echo "🔧 Applying quick fixes..."

# Stop any existing node processes
pkill -f "node.*node-build.mjs" || true
pkill -f "npm.*start" || true

# Start the app directly in background for immediate testing
cd $APP_DIR
echo "Starting app directly on 0.0.0.0:$PORT..."

# Set environment and start
export NODE_ENV=production
export HOST=0.0.0.0
export PORT=$PORT

# Start the app
sudo -u $APP_USER -E nohup node dist/server/node-build.mjs > /var/log/$APP_NAME/app.log 2>&1 &

# Wait for app to start
sleep 3

# Test if app is responding
if curl -s http://localhost:$PORT/api/ping > /dev/null; then
    echo "✅ App is responding on port $PORT"
else
    echo "❌ App is not responding. Check logs:"
    echo "   tail -f /var/log/$APP_NAME/app.log"
fi

# Restart nginx
systemctl restart nginx

echo ""
echo "🌐 Test your app:"
PUBLIC_IP=\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "YOUR_EC2_PUBLIC_IP")
echo "   http://\$PUBLIC_IP"
echo ""
echo "📋 Check status:"
echo "   curl -I http://\$PUBLIC_IP"
echo "   ps aux | grep node"
EOF

chmod +x $APP_DIR/quick-fix.sh

print_status "✅ Amazon Linux 2023 setup completed!"
print_status ""
print_status "📋 NEXT STEPS:"
print_status "1. Upload your application code to $APP_DIR"
print_status "2. Ensure you have the built dist/ folder"
print_status "3. Run: sudo $APP_DIR/quick-fix.sh (for immediate testing)"
print_status "4. Or run: sudo $APP_DIR/complete-deployment.sh (for full deployment)"
print_status ""
print_status "🚨 AWS SECURITY GROUP REQUIREMENTS:"
print_status "   - HTTP (port 80): 0.0.0.0/0"
print_status "   - HTTPS (port 443): 0.0.0.0/0"
print_status "   - SSH (port 22): Your IP only"
print_status ""
print_status "🔧 Troubleshooting commands:"
print_status "   sudo systemctl status nginx"
print_status "   sudo systemctl status $APP_NAME"
print_status "   sudo firewall-cmd --list-all"
print_status "   curl -I http://localhost"

print_warning "Don't forget to:"
print_warning "- Copy your app files to $APP_DIR"
print_warning "- Check AWS Security Group allows HTTP traffic"
print_warning "- Update environment variables in $APP_DIR/.env"
