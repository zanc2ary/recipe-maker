# RecipeAI - AWS EC2 Deployment Guide

This guide will help you deploy your RecipeAI web application to AWS EC2 for production use.

## Prerequisites

### 1. AWS EC2 Instance Setup
- **Instance Type**: t3.small or larger (minimum 2GB RAM)
- **AMI**: Ubuntu 22.04 LTS
- **Storage**: 20GB+ SSD
- **Security Group**: Configure ports:
  - SSH (22) - Your IP only
  - HTTP (80) - Anywhere
  - HTTPS (443) - Anywhere

### 2. Domain Name (Optional but Recommended)
- Register a domain or use a subdomain
- Point DNS A record to your EC2 instance's public IP

## Quick Deployment Steps

### Step 1: Connect to Your EC2 Instance
```bash
ssh -i your-key.pem ubuntu@your-ec2-public-ip
```

### Step 2: Download and Run the Setup Script
```bash
# Download the setup script
wget https://raw.githubusercontent.com/your-repo/main/deploy-to-ec2.sh

# Make it executable
chmod +x deploy-to-ec2.sh

# Run the setup (as root)
sudo ./deploy-to-ec2.sh
```

### Step 3: Upload Your Application Code
You can upload your code using one of these methods:

#### Option A: Using SCP (Secure Copy)
```bash
# From your local machine, copy the entire project
scp -i your-key.pem -r ./your-project/ ubuntu@your-ec2-ip:/tmp/app

# On EC2, move to correct location
sudo mv /tmp/app/* /opt/recipeai/
sudo chown -R recipeai:recipeai /opt/recipeai/
```

#### Option B: Using Git
```bash
# On EC2 instance
cd /opt/recipeai
sudo -u recipeai git clone https://github.com/your-username/your-repo.git .
```

#### Option C: Using AWS CodeDeploy
Set up automated deployment from your Git repository.

### Step 4: Configure Environment Variables
```bash
# Edit the environment file
sudo nano /opt/recipeai/.env
```

Add your production variables:
```env
NODE_ENV=production
PORT=3000

# Your Lambda API endpoint (already working)
LAMBDA_API_URL=https://t34tfhi733.execute-api.ap-southeast-2.amazonaws.com/prod/recommend

# Add any other environment variables your app needs
```

### Step 5: Update Domain Configuration
```bash
# Edit nginx configuration
sudo nano /etc/nginx/sites-available/recipeai

# Replace 'your-domain.com' with your actual domain
# Save and exit
```

### Step 6: Complete the Deployment
```bash
sudo /opt/recipeai/complete-deployment.sh
```

### Step 7: Set Up SSL Certificate (Recommended)
```bash
# Only run this after your domain DNS is pointing to your EC2 instance
sudo /opt/recipeai/setup-ssl.sh
```

## Application Structure on EC2

```
/opt/recipeai/                  # Main application directory
├── client/                     # React frontend code
├── server/                     # Express backend code
├── shared/                     # Shared types/utilities
├── dist/                       # Built application files
├── .env                        # Environment variables
├── ecosystem.config.js         # PM2 configuration
├── build-and-deploy.sh         # Build script
├── complete-deployment.sh      # Deployment completion script
└── setup-ssl.sh               # SSL setup script

/etc/nginx/sites-available/recipeai  # Nginx configuration
/var/log/recipeai/                   # Application logs
/etc/systemd/system/recipeai.service # Systemd service
```

## Monitoring and Management

### Check Application Status
```bash
# View application status
sudo systemctl status recipeai

# View nginx status
sudo systemctl status nginx

# View application logs
sudo pm2 logs recipeai

# Monitor all processes
sudo pm2 monit
```

### Common Management Commands
```bash
# Restart the application
sudo systemctl restart recipeai

# Restart nginx
sudo systemctl restart nginx

# Update application code and rebuild
cd /opt/recipeai
sudo -u recipeai git pull
sudo -u recipeai ./build-and-deploy.sh
sudo systemctl restart recipeai

# View error logs
sudo tail -f /var/log/recipeai/error.log
```

## Security Considerations

### 1. Firewall Configuration
The setup script configures UFW firewall to:
- Allow SSH (port 22)
- Allow HTTP/HTTPS (ports 80/443)
- Deny all other incoming traffic

### 2. Application Security
- Application runs as non-root user `recipeai`
- Environment variables stored securely
- Nginx configured with security headers
- PM2 manages process with automatic restarts

### 3. SSL/TLS
- Free SSL certificates via Let's Encrypt
- Automatic certificate renewal
- HTTPS redirect for secure connections

## Scaling and Performance

### Vertical Scaling
- Upgrade EC2 instance type for more CPU/RAM
- Current setup uses PM2 cluster mode for multi-core utilization

### Horizontal Scaling
- Add Application Load Balancer
- Deploy to multiple EC2 instances
- Use RDS for database clustering
- Implement Redis for session storage

### Performance Monitoring
```bash
# CPU and memory usage
htop

# Application performance
sudo pm2 monit

# Nginx access logs
sudo tail -f /var/log/nginx/access.log

# Application logs
sudo pm2 logs recipeai
```

## Troubleshooting

### Common Issues

1. **Application won't start**
   ```bash
   # Check logs
   sudo pm2 logs recipeai
   sudo systemctl status recipeai
   ```

2. **502 Bad Gateway**
   ```bash
   # Check if app is running
   sudo pm2 status
   # Check nginx configuration
   sudo nginx -t
   ```

3. **SSL Certificate Issues**
   ```bash
   # Verify domain DNS
   nslookup your-domain.com
   # Check certificate status
   sudo certbot certificates
   ```

### Log Locations
- Application logs: `/var/log/recipeai/`
- Nginx logs: `/var/log/nginx/`
- System logs: `sudo journalctl -u recipeai`

## Backup and Recovery

### Regular Backups
1. **Application Code**: Stored in Git repository
2. **Environment Config**: Backup `.env` file
3. **SSL Certificates**: Auto-renewed by certbot
4. **Database**: If using local database, set up regular backups

### Disaster Recovery
1. Launch new EC2 instance
2. Run deployment script
3. Restore environment configuration
4. Deploy latest code from Git

## Cost Optimization

### EC2 Instance Recommendations
- **Development/Testing**: t3.micro (1GB RAM)
- **Small Production**: t3.small (2GB RAM)
- **Medium Production**: t3.medium (4GB RAM)
- **High Traffic**: t3.large+ or c5 instances

### Additional AWS Services
- **CloudFront**: CDN for static assets
- **Route 53**: DNS management
- **Certificate Manager**: Free SSL certificates
- **CloudWatch**: Monitoring and alerts
- **S3**: Static asset storage

## Support

For deployment issues or questions:
1. Check the troubleshooting section above
2. Review application logs
3. Verify all configuration files
4. Ensure environment variables are set correctly

Your RecipeAI application should now be running at:
- **HTTP**: `http://your-domain.com`
- **HTTPS**: `https://your-domain.com` (after SSL setup)

🎉 **Congratulations!** Your recipe builder app is now deployed to production on AWS EC2!
