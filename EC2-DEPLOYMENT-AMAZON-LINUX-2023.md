# EC2 Deployment Guide - Amazon Linux 2023

Deploy your React + Express JavaScript application on Amazon Linux 2023 EC2 instance running on port 3000.

## Prerequisites Setup

### 1. Install Node.js (Latest LTS)
```bash
# Update system
sudo dnf update -y

# Install Node.js via NodeSource repository
curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
sudo dnf install -y nodejs

# Verify installation
node --version
npm --version
```

### 2. Install Git (if not already installed)
```bash
sudo dnf install -y git
```

### 3. Install PM2 for Process Management
```bash
sudo npm install -g pm2
```

## Application Deployment

### 1. Clone or Upload Your Application
```bash
# Option A: Clone from repository (replace with your repo URL)
git clone <your-repo-url> fusion-app
cd fusion-app

# Option B: If uploading files manually, create directory
mkdir fusion-app
cd fusion-app
# Then upload your files via SCP or similar
```

### 2. Install Dependencies
```bash
# Install all project dependencies
npm install
```

### 3. Build the Application
```bash
# Build both client and server
npm run build
```

### 4. Environment Configuration
```bash
# Create environment file
cat > .env << EOF
PORT=3000
NODE_ENV=production
PING_MESSAGE="Production server is running!"
EOF
```

### 5. Test the Application
```bash
# Test production build locally first
npm start

# In another terminal, test the API
curl http://localhost:3000/api/ping

# If working, stop with Ctrl+C
```

## Production Setup with PM2

### 1. Create PM2 Configuration
```bash
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'fusion-app',
    script: 'dist/server/node-build.mjs',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    }
  }]
}
EOF
```

### 2. Start Application with PM2
```bash
# Start the application
pm2 start ecosystem.config.js

# Check status
pm2 status

# View logs
pm2 logs fusion-app

# Save PM2 configuration for auto-restart on reboot
pm2 save
pm2 startup
# Follow the instructions provided by the startup command
```

### 3. Configure PM2 Auto-start on Boot
```bash
# Generate startup script (run the command PM2 provides)
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u ec2-user --hp /home/ec2-user
```

## Security Group Configuration

### Configure AWS Security Group
In your AWS Console, ensure your EC2 security group allows:
- **Inbound Rule**: Custom TCP, Port 3000, Source: 0.0.0.0/0 (or your specific IP range)
- **Outbound Rule**: All traffic (default)

## Firewall Configuration (if enabled)

### Configure firewalld (if running)
```bash
# Check if firewalld is running
sudo systemctl status firewalld

# If running, open port 3000
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --reload
```

## Testing the Deployment

### 1. Test Local Access
```bash
# Test API endpoint
curl http://localhost:3000/api/ping

# Test frontend (should return HTML)
curl http://localhost:3000
```

### 2. Test External Access
```bash
# Replace YOUR_EC2_PUBLIC_IP with your actual EC2 public IP
curl http://YOUR_EC2_PUBLIC_IP:3000/api/ping
```

### 3. Browser Test
Open in browser: `http://YOUR_EC2_PUBLIC_IP:3000`

## Optional: Setup Nginx Reverse Proxy

### 1. Install Nginx
```bash
sudo dnf install -y nginx
```

### 2. Configure Nginx
```bash
sudo cat > /etc/nginx/conf.d/fusion-app.conf << 'EOF'
server {
    listen 80;
    server_name YOUR_DOMAIN_OR_IP;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF
```

### 3. Start Nginx
```bash
sudo systemctl enable nginx
sudo systemctl start nginx

# Update security group to allow port 80 instead of 3000
```

## Management Commands

### PM2 Management
```bash
# View application status
pm2 status

# View logs
pm2 logs fusion-app

# Restart application
pm2 restart fusion-app

# Stop application
pm2 stop fusion-app

# Monitor resources
pm2 monit
```

### Application Updates
```bash
# Pull latest changes
git pull

# Rebuild application
npm run build

# Restart with PM2
pm2 restart fusion-app
```

### System Monitoring
```bash
# Check disk space
df -h

# Check memory usage
free -h

# Check CPU usage
top

# Check application processes
ps aux | grep node
```

## Troubleshooting

### Common Issues

1. **Port 3000 not accessible externally**
   - Check security group settings
   - Verify firewall configuration
   - Ensure app is binding to 0.0.0.0, not just localhost

2. **Application won't start**
   - Check logs: `pm2 logs fusion-app`
   - Verify build completed: `ls -la dist/`
   - Check environment variables: `pm2 env 0`

3. **Out of memory**
   - Monitor with: `pm2 monit`
   - Increase EC2 instance size if needed
   - Check for memory leaks in logs

### Useful Commands
```bash
# Check what's running on port 3000
sudo netstat -tulpn | grep :3000

# Check PM2 processes
pm2 list

# Restart all PM2 processes
pm2 restart all

# Check system resources
htop
```

## Security Best Practices

1. **Update system regularly**
   ```bash
   sudo dnf update -y
   ```

2. **Configure proper security groups** (minimal required ports)

3. **Use environment variables** for sensitive data

4. **Monitor logs regularly**
   ```bash
   pm2 logs --lines 100
   ```

5. **Set up log rotation**
   ```bash
   pm2 install pm2-logrotate
   ```

## Quick Deployment Script

Create a deploy script for easy updates:

```bash
cat > deploy.sh << 'EOF'
#!/bin/bash
echo "Deploying Fusion App..."

# Pull latest changes
git pull

# Install dependencies
npm install

# Build application
npm run build

# Restart with PM2
pm2 restart fusion-app

echo "Deployment complete!"
echo "Check status with: pm2 status"
echo "View logs with: pm2 logs fusion-app"
EOF

chmod +x deploy.sh
```

Your application should now be running on `http://YOUR_EC2_PUBLIC_IP:3000`!
