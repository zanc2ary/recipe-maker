#!/bin/bash

# RecipeAI Web App - AWS EC2 Deployment Script
# This script sets up a complete production environment on Ubuntu EC2

set -e  # Exit on any error

echo "🚀 Starting RecipeAI deployment on AWS EC2..."

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
apt update && apt upgrade -y

print_status "Installing required packages..."
apt install -y curl wget git nginx ufw build-essential software-properties-common

# Install Node.js 18.x
print_status "Installing Node.js 18.x..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

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

# Clone or copy your application code
print_status "Setting up application code..."
# Note: Replace this with your actual repository or upload method
cd $APP_DIR

# For now, we'll create the directory structure
# In practice, you would either:
# 1. Clone from git: git clone <your-repo-url> .
# 2. Upload files via SCP/SFTP
# 3. Use AWS CodeDeploy
print_warning "APPLICATION CODE SETUP REQUIRED:"
print_warning "You need to copy your application files to $APP_DIR"
print_warning "This includes: package.json, client/, server/, shared/, etc."

# Create environment file template
print_status "Creating environment configuration..."
cat > $APP_DIR/.env << EOF
# Production Environment Variables
NODE_ENV=production
PORT=$PORT

# Add your environment variables here
# LAMBDA_API_URL=https://your-lambda-api-url
# DB_CONNECTION_STRING=your-db-connection
# API_KEYS=your-api-keys

# Security
SESSION_SECRET=your-super-secret-session-key-change-this
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
      PORT: $PORT
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: $PORT
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

# Configure Nginx
print_status "Configuring Nginx reverse proxy..."
cat > /etc/nginx/sites-available/$APP_NAME << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/javascript;

    location / {
        proxy_pass http://localhost:$PORT;
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
    }

    # Static files caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        proxy_pass http://localhost:$PORT;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Security: Hide nginx version
    server_tokens off;
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
print_status "Testing Nginx configuration..."
nginx -t

# Configure firewall
print_status "Configuring UFW firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

# Create systemd service for PM2
print_status "Setting up PM2 auto-start..."
sudo -u $APP_USER pm2 startup systemd -u $APP_USER --hp $APP_DIR
# Note: The above command will output a command that needs to be run as root
# We'll create a manual systemd service instead

cat > /etc/systemd/system/$APP_NAME.service << EOF
[Unit]
Description=$APP_NAME
After=network.target

[Service]
Type=forking
User=$APP_USER
WorkingDirectory=$APP_DIR
Environment=PATH=/usr/bin:/usr/local/bin
Environment=PM2_HOME=$APP_DIR/.pm2
ExecStart=/usr/bin/pm2 start ecosystem.config.js --env production
ExecReload=/usr/bin/pm2 reload ecosystem.config.js --env production
ExecStop=/usr/bin/pm2 kill
KillMode=process
Restart=on-failure
RestartSec=10

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

# Create SSL setup script (optional)
print_status "Creating SSL setup script..."
cat > $APP_DIR/setup-ssl.sh << EOF
#!/bin/bash
# Run this script after setting up your domain DNS

# Install Certbot
apt update
apt install -y certbot python3-certbot-nginx

# Get SSL certificate
certbot --nginx -d $DOMAIN -d www.$DOMAIN

# Test automatic renewal
certbot renew --dry-run

echo "SSL certificate installed successfully!"
echo "Your app will be available at https://$DOMAIN"
EOF

chmod +x $APP_DIR/setup-ssl.sh

# Set ownership
chown -R $APP_USER:$APP_USER $APP_DIR

print_status "Creating deployment completion script..."
cat > $APP_DIR/complete-deployment.sh << EOF
#!/bin/bash
# Run this script after uploading your application code

set -e

echo "Completing $APP_NAME deployment..."

# Build the application
sudo -u $APP_USER $APP_DIR/build-and-deploy.sh

# Enable and start services
systemctl daemon-reload
systemctl enable $APP_NAME
systemctl start $APP_NAME
systemctl restart nginx

# Check status
systemctl status $APP_NAME --no-pager
systemctl status nginx --no-pager

echo ""
echo "🎉 Deployment completed!"
echo "📋 Next steps:"
echo "   1. Copy your application code to $APP_DIR"
echo "   2. Edit $APP_DIR/.env with your environment variables"
echo "   3. Run: sudo $APP_DIR/complete-deployment.sh"
echo "   4. Optional: Run $APP_DIR/setup-ssl.sh for HTTPS"
echo ""
echo "🌐 Your app will be available at:"
echo "   HTTP:  http://$DOMAIN"
echo "   HTTPS: https://$DOMAIN (after SSL setup)"
echo ""
echo "📊 Monitoring commands:"
echo "   sudo systemctl status $APP_NAME"
echo "   sudo pm2 logs $APP_NAME"
echo "   sudo pm2 monit"
EOF

chmod +x $APP_DIR/complete-deployment.sh

print_status "✅ Basic setup completed!"
print_status ""
print_status "📋 MANUAL STEPS REQUIRED:"
print_status "1. Upload your application code to $APP_DIR"
print_status "2. Edit $APP_DIR/.env with your environment variables"
print_status "3. Update the domain name in /etc/nginx/sites-available/$APP_NAME"
print_status "4. Run: sudo $APP_DIR/complete-deployment.sh"
print_status "5. Optional: Run $APP_DIR/setup-ssl.sh for HTTPS"
print_status ""
print_status "🔧 Useful commands:"
print_status "   View app logs: sudo pm2 logs $APP_NAME"
print_status "   Restart app: sudo systemctl restart $APP_NAME"
print_status "   View app status: sudo systemctl status $APP_NAME"
print_status "   Monitor processes: sudo pm2 monit"

print_warning "Don't forget to:"
print_warning "- Set up your domain DNS to point to this EC2 instance"
print_warning "- Configure your security groups to allow HTTP (80) and HTTPS (443)"
print_warning "- Update environment variables in $APP_DIR/.env"
