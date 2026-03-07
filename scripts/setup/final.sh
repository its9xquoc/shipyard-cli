
# ===================================================================
# SSL CERTIFICATE
# ===================================================================

setup_ssl() {
    log_header "SETTING UP SSL CERTIFICATE"
    
    if [[ "$DOMAIN" == "_" || "$DOMAIN" == "your-domain.com" ]]; then
        log_warning "Domain not configured - skipping SSL setup"
        log_info "Update DOMAIN and EMAIL variables to enable SSL"
        return 0
    fi
    
    if [[ "$EMAIL" == "your-email@domain.com" ]]; then
        log_warning "Email not configured - skipping SSL setup"
        return 0
    fi
    
    log_info "Installing Certbot..."
    snap install core
    snap refresh core
    snap install --classic certbot
    ln -sf /snap/bin/certbot /usr/bin/certbot
    
    log_info "Obtaining SSL certificate for $DOMAIN..."
    certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        --redirect
    
    # Setup auto-renewal
    systemctl enable snap.certbot.renew.timer
    
    log_success "SSL certificate installed for $DOMAIN"
}

# ===================================================================
# WEB DIRECTORY SETUP
# ===================================================================

create_default_site() {
    log_header "CREATING DEFAULT WEBSITE"
    
    log_info "Setting up web directory..."
    mkdir -p "${WEB_ROOT}/html"
    
    # Create default site configuration
    cat > /etc/nginx/sites-available/default <<EOF
# ===================================================================
# Default Site Configuration
# ===================================================================

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name ${DOMAIN} _;
    
    root ${WEB_ROOT}/html;
    index index.php index.html index.htm;
    
    # Logging
    access_log /var/log/nginx/default-access.log main;
    error_log /var/log/nginx/default-error.log warn;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Main location
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # PHP processing
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        
        # PHP security
        fastcgi_hide_header X-Powered-By;
        fastcgi_intercept_errors on;
    }
    
    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Deny access to backup files
    location ~ ~$ {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Static file caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/
    
    # Create welcome page
    cat > "${WEB_ROOT}/html/index.php" <<'EOFHTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VPS Setup Complete</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            padding: 60px 40px;
            max-width: 800px;
            width: 100%;
        }
        h1 {
            color: #667eea;
            font-size: 3em;
            margin-bottom: 20px;
            text-align: center;
        }
        .status {
            background: #10b981;
            color: white;
            padding: 15px 30px;
            border-radius: 50px;
            display: inline-block;
            margin: 20px auto;
            font-weight: bold;
            display: block;
            text-align: center;
        }
        .info {
            background: #f3f4f6;
            border-radius: 10px;
            padding: 30px;
            margin: 30px 0;
        }
        .info-row {
            display: flex;
            justify-content: space-between;
            padding: 15px 0;
            border-bottom: 1px solid #e5e7eb;
        }
        .info-row:last-child { border-bottom: none; }
        .label { font-weight: 600; color: #6b7280; }
        .value { color: #111827; font-family: monospace; }
        .success { color: #10b981; font-size: 4em; text-align: center; margin: 20px 0; }
        .footer {
            text-align: center;
            color: #6b7280;
            margin-top: 30px;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="success">✓</div>
        <h1>VPS Setup Complete!</h1>
        <div class="status">Server is running successfully</div>
        
        <div class="info">
            <div class="info-row">
                <span class="label">Server Time</span>
                <span class="value"><?php echo date('Y-m-d H:i:s'); ?></span>
            </div>
            <div class="info-row">
                <span class="label">PHP Version</span>
                <span class="value"><?php echo phpversion(); ?></span>
            </div>
            <div class="info-row">
                <span class="label">Web Server</span>
                <span class="value"><?php echo $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown'; ?></span>
            </div>
            <div class="info-row">
                <span class="label">Server Name</span>
                <span class="value"><?php echo gethostname(); ?></span>
            </div>
        </div>
        
        <div class="footer">
            <p>🎉 Your VPS is ready to deploy applications!</p>
            <p>Remove or replace this file at: /var/www/html/index.php</p>
        </div>
    </div>
</body>
</html>
EOFHTML

    # Set proper permissions
    chown -R www-data:www-data "${WEB_ROOT}/html"
    chmod -R 755 "${WEB_ROOT}/html"
    
    # Set www-data directory permissions
    chown -R root:www-data "${WEB_ROOT}"
    chmod -R 775 "${WEB_ROOT}"
    
    # Add deploy user to www-data group
    usermod -aG www-data "$NEW_USER"
    
    # Test Nginx configuration
    if nginx -t; then
        systemctl reload nginx
        log_success "Default site created"
    else
        log_error "Nginx configuration test failed"
        exit 1
    fi
}

# ===================================================================
# SYSTEM OPTIMIZATION
# ===================================================================

optimize_system() {
    log_header "OPTIMIZING SYSTEM PERFORMANCE"
    
    log_info "Configuring system limits..."
    
    cat >> /etc/security/limits.conf <<EOF

# Custom limits for VPS optimization
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
www-data soft nofile 65536
www-data hard nofile 65536
EOF

    log_info "Optimizing kernel parameters..."
    
    backup_file "/etc/sysctl.conf"
    
    cat >> /etc/sysctl.conf <<EOF

# ===================================================================
# Custom Kernel Optimizations
# ===================================================================

# Network Performance
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# TCP Tuning
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1

# File System
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288

# Memory Management
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5

# Security
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
EOF

    sysctl -p
    
    log_info "Configuring log rotation..."
    
    cat > /etc/logrotate.d/custom-vps <<EOF
# Custom log rotation for VPS
${WEB_ROOT}/*/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    sharedscripts
    postrotate
        systemctl reload nginx > /dev/null
    endscript
}

/var/log/nginx/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        systemctl reload nginx > /dev/null
    endscript
}
EOF

    log_success "System optimizations applied"
}

# ===================================================================
# DEPLOYMENT HELPERS
# ===================================================================

create_deployment_scripts() {
    log_header "CREATING DEPLOYMENT SCRIPTS"
    
    # Main deployment script
    cat > "/home/$NEW_USER/deploy.sh" <<'EOFDEPLOY'
#!/bin/bash
# ===================================================================
# Application Deployment Script
# ===================================================================
# Usage: ./deploy.sh <repository-url> <app-name> [branch]
# ===================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default values
BRANCH="${3:-main}"
WEB_ROOT="/var/www"

# Check arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <repository-url> <app-name> [branch]"
    echo "Example: $0 https://github.com/user/repo.git myapp main"
    exit 1
fi

REPO_URL="$1"
APP_NAME="$2"
APP_PATH="${WEB_ROOT}/${APP_NAME}"

echo -e "${GREEN}🚀 Deploying: ${APP_NAME}${NC}"
echo "======================================"
echo "Repository: ${REPO_URL}"
echo "Branch: ${BRANCH}"
echo "Path: ${APP_PATH}"
echo "======================================"

# Clone or update repository
if [[ -d "${APP_PATH}" ]]; then
    echo -e "${YELLOW}Updating existing application...${NC}"
    cd "${APP_PATH}"
    sudo git fetch origin
    sudo git reset --hard origin/${BRANCH}
    sudo git pull origin ${BRANCH}
else
    echo -e "${YELLOW}Cloning repository...${NC}"
    sudo mkdir -p "${APP_PATH}"
    sudo git clone "${REPO_URL}" "${APP_PATH}"
    cd "${APP_PATH}"
    sudo git checkout ${BRANCH}
fi

# Install PHP dependencies
if [[ -f "composer.json" ]]; then
    echo -e "${YELLOW}Installing PHP dependencies...${NC}"
    sudo composer install --no-interaction --prefer-dist --optimize-autoloader --no-dev
fi

# Install Node.js dependencies
if [[ -f "package.json" ]]; then
    echo -e "${YELLOW}Installing Node.js dependencies...${NC}"
    npm ci --production
    
    # Build assets
    if grep -q "\"build\"" package.json; then
        npm run build
    elif grep -q "\"production\"" package.json; then
        npm run production
    fi
fi

# Laravel specific setup
if [[ -f "artisan" ]]; then
    echo -e "${YELLOW}Setting up Laravel application...${NC}"
    
    # Copy environment file if not exists
    [[ ! -f .env ]] && sudo cp .env.example .env
    
    # Generate app key if not set
    if ! grep -q "APP_KEY=base64" .env; then
        sudo php artisan key:generate --force
    fi
    
    # Run migrations (optional, comment if not needed)
    # sudo php artisan migrate --force
    
    # Clear and cache
    sudo php artisan config:cache
    sudo php artisan route:cache
    sudo php artisan view:cache
fi

# Set correct permissions
echo -e "${YELLOW}Setting permissions...${NC}"
sudo chown -R www-data:www-data "${APP_PATH}"
sudo find "${APP_PATH}" -type f -exec chmod 644 {} \;
sudo find "${APP_PATH}" -type d -exec chmod 755 {} \;

# Laravel storage permissions
if [[ -d "storage" ]]; then
    sudo chmod -R 775 storage bootstrap/cache
fi

echo -e "${GREEN}✅ Deployment complete!${NC}"
echo "Application deployed to: ${APP_PATH}"
EOFDEPLOY

    # Create site script
    cat > "/home/$NEW_USER/create-site.sh" <<'EOFSITE'
#!/bin/bash
# ===================================================================
# Nginx Site Configuration Creator
# ===================================================================
# Usage: ./create-site.sh <domain> [app-path]
# ===================================================================

set -e

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root or with sudo"
    exit 1
fi

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <domain> [app-path]"
    echo "Example: $0 example.com /var/www/myapp"
    exit 1
fi

DOMAIN="$1"
APP_PATH="${2:-/var/www/${DOMAIN}}"
PHP_VERSION="8.4"

echo "Creating Nginx configuration for: ${DOMAIN}"
echo "Application path: ${APP_PATH}"

# Create application directory
mkdir -p "${APP_PATH}/public"

# Create Nginx configuration
cat > "/etc/nginx/sites-available/${DOMAIN}" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};
    
    root ${APP_PATH}/public;
    index index.php index.html index.htm;
    
    access_log /var/log/nginx/${DOMAIN}-access.log;
    error_log /var/log/nginx/${DOMAIN}-error.log;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF

# Enable site
ln -sf "/etc/nginx/sites-available/${DOMAIN}" "/etc/nginx/sites-enabled/"

# Test and reload Nginx
if nginx -t; then
    systemctl reload nginx
    echo "✅ Site configuration created for: ${DOMAIN}"
    echo "📁 Document root: ${APP_PATH}/public"
    echo "🌐 Run: certbot --nginx -d ${DOMAIN} -d www.${DOMAIN}"
else
    echo "❌ Nginx configuration test failed"
    exit 1
fi
EOFSITE

    # Set permissions
    chmod +x "/home/$NEW_USER/deploy.sh"
    chmod +x "/home/$NEW_USER/create-site.sh"
    chown "$NEW_USER:$NEW_USER" "/home/$NEW_USER/deploy.sh"
    chown "$NEW_USER:$NEW_USER" "/home/$NEW_USER/create-site.sh"
    
    log_success "Deployment scripts created in /home/$NEW_USER/"
}

# ===================================================================
# SAVE CREDENTIALS
# ===================================================================

save_credentials() {
    log_header "SAVING CREDENTIALS"
    
    local cred_file="/root/vps-credentials.txt"
    
    cat > "$cred_file" <<EOF
===================================================================
VPS SETUP CREDENTIALS
===================================================================
Generated: $(date)
Server: $(hostname)

-------------------------------------------------------------------
SYSTEM USER
-------------------------------------------------------------------
Username: ${NEW_USER}
Password: ${NEW_USER_PASSWORD}
Home: /home/${NEW_USER}

-------------------------------------------------------------------
SSH ACCESS
-------------------------------------------------------------------
SSH Port: ${SSH_PORT}
Command: ssh ${NEW_USER}@$(hostname -I | awk '{print $1}') -p ${SSH_PORT}

-------------------------------------------------------------------
DATABASE (MariaDB)
-------------------------------------------------------------------
Root Password: ${DB_ROOT_PASS}
Database: ${DB_NAME}
Username: ${DB_USER}
Password: ${DB_PASS}

Connection:
  mysql -u ${DB_USER} -p'${DB_PASS}' ${DB_NAME}

-------------------------------------------------------------------
REDIS
-------------------------------------------------------------------
Password: ${REDIS_PASS}

Connection:
  redis-cli
  AUTH ${REDIS_PASS}

-------------------------------------------------------------------
WEB SERVER
-------------------------------------------------------------------
Nginx Config: /etc/nginx/nginx.conf
Sites: /etc/nginx/sites-available/
Web Root: ${WEB_ROOT}
PHP Version: ${PHP_VERSION}

-------------------------------------------------------------------
IMPORTANT FILES
-------------------------------------------------------------------
- Deployment: /home/${NEW_USER}/deploy.sh
- Create Site: /home/${NEW_USER}/create-site.sh
- SSH Hardening: /home/${NEW_USER}/harden-ssh.sh
- Setup Log: ${LOG_FILE}

-------------------------------------------------------------------
NEXT STEPS
-------------------------------------------------------------------
1. Test SSH connection on port ${SSH_PORT}
2. Change password for ${NEW_USER}
3. Run ./harden-ssh.sh after testing
4. Configure domain DNS
5. Setup SSL: certbot --nginx -d domain.com

===================================================================
⚠️  KEEP THIS FILE SECURE - IT CONTAINS SENSITIVE INFORMATION
===================================================================
EOF

    chmod 600 "$cred_file"
    
    log_success "Credentials saved to: $cred_file"
}

# ===================================================================
# PRINT SUMMARY
# ===================================================================

print_summary() {
    log_header "SETUP COMPLETE!"
    
    local server_ip
    server_ip=$(hostname -I | awk '{print $1}')
    
    cat <<EOF

${GREEN}╔════════════════════════════════════════════════════════╗
║                                                        ║
║            🎉 VPS SETUP COMPLETED SUCCESSFULLY 🎉      ║
║                                                        ║
╚════════════════════════════════════════════════════════╝${NC}

${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${WHITE}INSTALLED COMPONENTS${NC}
${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
✓ Security & Firewall (UFW, Fail2Ban)
✓ Nginx $(nginx -v 2>&1 | cut -d'/' -f2)
✓ PHP ${PHP_VERSION}
✓ MariaDB $(mysql --version | awk '{print $5}' | cut -d',' -f1)
✓ Node.js $(node --version)
✓ Redis $(redis-server --version | awk '{print $3}' | cut -d'=' -f2)
✓ Composer $(composer --version | awk '{print $3}')
✓ PM2 $(pm2 --version)

${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${WHITE}ACCESS INFORMATION${NC}
${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${GREEN}Server IP:${NC} ${server_ip}
${GREEN}Website:${NC} http://${DOMAIN}
${GREEN}SSH Port:${NC} ${SSH_PORT}
${GREEN}SSH User:${NC} ${NEW_USER}

${YELLOW}SSH Command:${NC}
  ssh ${NEW_USER}@${server_ip} -p ${SSH_PORT}

${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${WHITE}IMPORTANT NEXT STEPS${NC}
${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${RED}⚠️  CRITICAL - DO NOT CLOSE THIS SESSION YET!${NC}

${YELLOW}1.${NC} Test SSH connection in a NEW terminal:
   ${GREEN}ssh ${NEW_USER}@${server_ip} -p ${SSH_PORT}${NC}
   Password: ${NEW_USER_PASSWORD}

${YELLOW}2.${NC} After successful login, change password:
   ${GREEN}passwd${NC}

${YELLOW}3.${NC} Harden SSH (disables password & root login):
   ${GREEN}./harden-ssh.sh${NC}

${YELLOW}4.${NC} Point your domain DNS to: ${server_ip}

${YELLOW}5.${NC} Setup SSL certificate:
   ${GREEN}sudo certbot --nginx -d yourdomain.com${NC}

${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${WHITE}USEFUL COMMANDS${NC}
${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
Deploy app:      ${GREEN}./deploy.sh <repo-url> <app-name>${NC}
Create site:     ${GREEN}sudo ./create-site.sh <domain>${NC}
Check services:  ${GREEN}systemctl status nginx php${PHP_VERSION}-fpm mariadb${NC}
View logs:       ${GREEN}tail -f /var/log/nginx/error.log${NC}
Firewall status: ${GREEN}sudo ufw status${NC}

${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${WHITE}CREDENTIALS${NC}
${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${RED}All credentials saved to:${NC} /root/vps-credentials.txt

${YELLOW}View credentials:${NC}
  ${GREEN}sudo cat /root/vps-credentials.txt${NC}

${RED}⚠️  Keep this file secure and backup it safely!${NC}

${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${WHITE}SUPPORT & LOGS${NC}
${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
Setup log: ${LOG_FILE}
Backups: ${BACKUP_DIR}

${GREEN}Happy deploying! 🚀${NC}

EOF
}

# ===================================================================
# CLEANUP & ERROR HANDLING
# ===================================================================

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script failed with exit code: $exit_code"
        log_info "Check log file: $LOG_FILE"
        log_info "Backup directory: $BACKUP_DIR"
    fi
}

trap cleanup EXIT

