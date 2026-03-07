#!/bin/bash
set -e

# ===============================
# VPS SETUP FROM SCRATCH SCRIPT
# ===============================
# Automated VPS Ubuntu/Debian setup from scratch
# Includes: Security, Firewall, Nginx, PHP, MariaDB, Node.js, SSL

# ===============================
# CONFIG SECTION
# ===============================
# Change the following information according to your needs
NEW_USER="deploy"                    # Non-root user
NEW_USER_PASSWORD="4Itxx17QvRsa"      # Temporary password for new user
SSH_PORT="2222"                      # New SSH port (not 22)
DOMAIN="_"             # Your actual domain
EMAIL="your-email@domain.com"        # Email for SSL certificate

# Database config
DB_ROOT_PASS="4Itxx17QvRsa"
DB_NAME="app_db"
DB_USER="app_user"
DB_PASS="4Itxx17QvRsa"

# PHP version
PHP_VERSION="8.4"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ===============================
# HELPER FUNCTIONS
# ===============================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script needs to be run with root privileges!"
        exit 1
    fi
}

# ===============================
# MAIN SETUP FUNCTIONS
# ===============================

setup_basic_security() {
    log_info "Setting up basic security..."
    
    # Update system
    apt update -y && apt upgrade -y
    
    # Install essential packages
    apt install -y curl wget git unzip software-properties-common \
        ca-certificates lsb-release apt-transport-https \
        fail2ban ufw htop nano vim tree

    # Create new user
    if ! id "$NEW_USER" &>/dev/null; then
        useradd -m -s /bin/bash "$NEW_USER"
        # user password
        echo "$NEW_USER:$NEW_USER_PASSWORD" | chpasswd
        usermod -aG sudo "$NEW_USER"
        usermod -a -G www-data "$NEW_USER"
        log_success "Created user: $NEW_USER"
    else
        log_warning "User $NEW_USER already exists"
    fi
    
    # Setup SSH keys for new user (copy from root)
    if [[ -d "/root/.ssh" && -f "/root/.ssh/authorized_keys" ]]; then
        mkdir -p "/home/$NEW_USER/.ssh"
        cp /root/.ssh/authorized_keys "/home/$NEW_USER/.ssh/" 2>/dev/null || true
        chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.ssh"
        chmod 700 "/home/$NEW_USER/.ssh"
        chmod 600 "/home/$NEW_USER/.ssh/authorized_keys" 2>/dev/null || true
        log_success "SSH keys copied to $NEW_USER"
    else
        log_warning "No SSH keys found in /root/.ssh/ - password auth will be needed"
        log_warning "Consider adding SSH keys before disabling password authentication"
        
        # Set a temporary password for the new user
        echo "$NEW_USER:TempPass123!" | chpasswd
        log_warning "Temporary password set for $NEW_USER: TempPass123!"
        log_warning "Change this password immediately after first login"
    fi
}

configure_ssh() {
    log_info "Configuring SSH security..."
    
    # Backup original SSH config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    log_warning "SSH will be configured but NOT restarted automatically to prevent lockout"
    
    # Configure SSH - SAFER approach
    cat > /etc/ssh/sshd_config <<EOF
# SSH Configuration for Security
Port $SSH_PORT
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Authentication - Keep some fallbacks initially
LoginGraceTime 60
PermitRootLogin yes
StrictModes yes
MaxAuthTries 6
MaxSessions 10

# Password Authentication - Keep enabled initially for safety
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Key Authentication
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Network
ClientAliveInterval 300
ClientAliveCountMax 2
TCPKeepAlive yes

# Misc
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

    # Test SSH config but DON'T restart yet
    if sshd -t; then
        sudo systemctl restart ssh
        log_success "SSH config is valid - ready for manual restart"
        log_warning "⚠️  SSH is listening on BOTH port 22 and $SSH_PORT for safety"
        log_warning "⚠️  You MUST manually restart SSH and test new connection before securing further"
    else
        log_error "SSH config test failed! Restoring backup..."
        cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
        exit 1
    fi

}

setup_firewall() {
    log_info "Setting up UFW firewall..."
    
    # Reset UFW
    ufw --force reset
    
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH on new port
    ufw allow "$SSH_PORT/tcp"
    
    # Allow HTTP/HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Enable firewall
    ufw --force enable
    
    log_success "Firewall configured"
}

setup_fail2ban() {
    log_info "Configuring Fail2Ban..."
    
    cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = $SSH_PORT
logpath = %(sshd_log)s

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10
EOF

    systemctl restart fail2ban
    log_success "Fail2Ban configured"
}

install_nginx() {
    log_info "Installing Nginx..."
    
    apt install -y nginx
    
    # Remove default site
    rm -f /etc/nginx/sites-enabled/default
    
    # Basic nginx config
    cat > /etc/nginx/nginx.conf <<EOF
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
    use epoll;
    multi_accept on;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    
    # MIME
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # Logging
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;
    
    # Gzip
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
    
    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=login:10m rate=10r/m;
    limit_req_zone \$binary_remote_addr zone=api:10m rate=100r/m;
    
    # Include configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

    # Test and start nginx
    nginx -t && systemctl enable nginx && systemctl start nginx
    log_success "Nginx installed and configured"
}

install_php() {
    log_info "Installing PHP $PHP_VERSION..."
    
    # Add Ondrej PHP repository
    add-apt-repository ppa:ondrej/php -y
    apt update -y
    
    # Install PHP and extensions
    apt install -y php${PHP_VERSION} php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-bcmath \
        php${PHP_VERSION}-curl php${PHP_VERSION}-zip php${PHP_VERSION}-intl \
        php${PHP_VERSION}-gd php${PHP_VERSION}-redis php${PHP_VERSION}-imagick
    
    # Configure PHP-FPM
    sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/${PHP_VERSION}/fpm/php.ini
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 64M/' /etc/php/${PHP_VERSION}/fpm/php.ini
    sed -i 's/post_max_size = .*/post_max_size = 64M/' /etc/php/${PHP_VERSION}/fpm/php.ini
    sed -i 's/memory_limit = .*/memory_limit = 512M/' /etc/php/${PHP_VERSION}/fpm/php.ini
    sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/${PHP_VERSION}/fpm/php.ini
    
    systemctl enable php${PHP_VERSION}-fpm
    systemctl start php${PHP_VERSION}-fpm
    
    log_success "PHP $PHP_VERSION installed"
}

install_composer() {
    log_info "Installing Composer..."
    
    if ! command -v composer &> /dev/null; then
        curl -sS https://getcomposer.org/installer -o composer-setup.php
        php composer-setup.php --install-dir=/usr/local/bin --filename=composer
        rm composer-setup.php
        chmod +x /usr/local/bin/composer
        log_success "Composer installed"
    else
        log_warning "Composer already installed"
    fi
}

install_nodejs() {
    log_info "Installing Node.js..."
    
    # Install Node.js 20 LTS
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y nodejs
    
    # Install global packages
    npm install -g pm2 yarn
    
    log_success "Node.js and PM2 installed"
}

install_mariadb() {
    log_info "Installing MariaDB..."
    
    apt install -y mariadb-server mariadb-client
    
    systemctl enable mariadb
    systemctl start mariadb
    
    log_info "Securing MariaDB installation..."
    
    # Use HERE document for better compatibility
    mysql <<EOF
-- Secure MariaDB installation
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

    log_info "Creating application database and user..."
    
    # Create application database and user
    mysql -u root -p"${DB_ROOT_PASS}" <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    # Test the connection
    if mysql -u root -p"${DB_ROOT_PASS}" -e "SELECT 1;" >/dev/null 2>&1; then
        log_success "MariaDB installed and secured successfully"
    else
        log_error "MariaDB setup may have issues, but continuing..."
    fi
}

install_redis() {
    log_info "Installing Redis..."
    
    apt install -y redis-server
    
    # Configure Redis
    sed -i 's/# requirepass .*/requirepass SecureRedisPass123!/' /etc/redis/redis.conf
    sed -i 's/bind 127.0.0.1 ::1/bind 127.0.0.1/' /etc/redis/redis.conf
    
    systemctl enable redis-server
    systemctl restart redis-server
    
    log_success "Redis installed and configured"
}

setup_ssl() {
    log_info "Setting up SSL with Certbot..."
    
    if [[ "$DOMAIN" != "your-domain.com" && "$EMAIL" != "your-email@domain.com" ]]; then
        # Install Certbot
        snap install core; snap refresh core
        snap install --classic certbot
        ln -sf /snap/bin/certbot /usr/bin/certbot
        
        # Create basic site first
        create_default_site
        
        # Get SSL certificate
        certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL"
        
        # Setup auto-renewal
        echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -
        
        log_success "SSL certificate installed for $DOMAIN"
    else
        log_warning "Skipping SSL setup - please configure DOMAIN and EMAIL variables"
    fi
}

create_default_site() {
    log_info "Creating default site..."

    sudo usermod -aG www-data $NEW_USER
    sudo chown -R root:www-data /var/www
    sudo chmod -R 775 /var/www
    
    # Create web directory
    mkdir -p /var/www/html
    
    # Create default nginx site
    cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80;
    server_name $DOMAIN _;
    root /var/www/html;
    index index.php index.html index.htm;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/
    
    # Create PHP info page
    cat > /var/www/html/index.php <<EOF
<?php
echo "<h1>VPS Setup Complete!</h1>";
echo "<p>Server is running PHP " . phpversion() . "</p>";
echo "<p>Server time: " . date('Y-m-d H:i:s') . "</p>";
phpinfo();
?>
EOF

    chown -R www-data:www-data /var/www/html
    nginx -t && systemctl reload nginx
}

optimize_system() {
    log_info "Optimizing system performance..."
    
    # Increase file limits
    cat >> /etc/security/limits.conf <<EOF
* soft nofile 65536
* hard nofile 65536
EOF

    # Optimize sysctl
    cat >> /etc/sysctl.conf <<EOF
# Network optimizations
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr

# File system
fs.file-max = 2097152
vm.swappiness = 10
EOF

    sysctl -p
    
    # Setup log rotation
    cat > /etc/logrotate.d/custom <<EOF
/var/log/nginx/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    sharedscripts
    postrotate
        /bin/kill -USR1 \$(cat /var/run/nginx.pid 2>/dev/null) 2>/dev/null || true
    endscript
}
EOF

    log_success "System optimized"
}

create_deploy_script() {
    log_info "Creating deployment helpers..."
    
    # Create deployment script for the new user
    cat > /home/$NEW_USER/deploy.sh <<'EOF'
#!/bin/bash
# Simple deployment script
# Usage: ./deploy.sh <git-repo-url> <app-name>

set -e

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <git-repo-url> <app-name>"
    exit 1
fi

REPO_URL="$1"
APP_NAME="$2"
APP_PATH="/var/www/$APP_NAME"

echo "Deploying $APP_NAME from $REPO_URL..."

# Clone or update
if [[ -d "$APP_PATH" ]]; then
    cd "$APP_PATH" && git pull origin main
else
    sudo git clone "$REPO_URL" "$APP_PATH"
fi

cd "$APP_PATH"

# Install dependencies if it's a PHP project
if [[ -f "composer.json" ]]; then
    sudo composer install --no-interaction --prefer-dist --optimize-autoloader
fi

# Install Node.js dependencies
if [[ -f "package.json" ]]; then
    npm install
    npm run build 2>/dev/null || npm run production 2>/dev/null || true
fi

# Set permissions
sudo chown -R www-data:www-data "$APP_PATH"
sudo chmod -R 755 "$APP_PATH"
sudo chmod -R 775 "$APP_PATH/storage" 2>/dev/null || true
sudo chmod -R 775 "$APP_PATH/bootstrap/cache" 2>/dev/null || true

echo "Deployment complete!"
EOF

    chmod +x /home/$NEW_USER/deploy.sh
    chown $NEW_USER:$NEW_USER /home/$NEW_USER/deploy.sh
    
    # Create SSH security script
    cat > /home/$NEW_USER/secure-ssh.sh <<'EOF'
#!/bin/bash
# SSH Security Hardening Script
# Run this ONLY after testing SSH connection on new port

echo "🔐 SSH Security Hardening"
echo "========================="
echo "This will:"
echo "1. Disable root login"
echo "2. Disable password authentication"  
echo "3. Use only the new SSH port"
echo ""
read -p "Are you sure? This may lock you out if not configured properly! (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

# Harden SSH config
sudo tee /etc/ssh/sshd_config > /dev/null <<EOSSH
# SSH Configuration - HARDENED
Port 2222
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Authentication - HARDENED
LoginGraceTime 60
PermitRootLogin no
StrictModes yes
MaxAuthTries 3
MaxSessions 2

# Password Authentication - DISABLED
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Key Authentication
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Network
ClientAliveInterval 300
ClientAliveCountMax 2
TCPKeepAlive yes

# Misc
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOSSH

# Test and restart SSH
if sudo sshd -t; then
    sudo systemctl restart ssh
    echo "✅ SSH hardened successfully!"
    echo "⚠️  From now on, use: ssh $USER@server -p 2222"
else
    echo "❌ SSH config error! Not restarting."
fi
EOF

    chmod +x /home/$NEW_USER/secure-ssh.sh
    chown $NEW_USER:$NEW_USER /home/$NEW_USER/secure-ssh.sh
    
    log_success "Deploy script created at /home/$NEW_USER/deploy.sh"
    log_success "SSH security script created at /home/$NEW_USER/secure-ssh.sh"
}

# ===============================
# MAIN EXECUTION
# ===============================
main() {
    log_info "Starting VPS setup from scratch..."
    log_warning "This will configure: Security, Firewall, Nginx, PHP, MariaDB, Node.js, Redis"
    
    check_root
    
    echo
    read -p "Continue with VPS setup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Setup cancelled"
        exit 0
    fi

    # Execute setup steps
    setup_basic_security
    configure_ssh
    setup_firewall
    # setup_fail2ban
    install_nginx
    install_php
    install_composer
    install_nodejs
    install_mariadb
    install_redis
    create_default_site
    optimize_system
    # setup_ssl
    # create_deploy_script

    # Final message
    echo
    log_success "🎉 VPS Setup Complete!"
    echo "=================================="
    echo "✅ Security configured"
    echo "✅ SSH port changed to: $SSH_PORT"
    echo "✅ Firewall enabled"
    echo "✅ Nginx installed"
    echo "✅ PHP $PHP_VERSION installed"
    echo "✅ MariaDB secured"
    echo "✅ Node.js & PM2 installed"
    echo "✅ Redis configured"
    echo "=================================="
    echo "🔗 Website: http://$DOMAIN"
    echo "👤 User: $NEW_USER (sudo access)"
    echo "🔑 SSH: ssh $NEW_USER@your-server -p $SSH_PORT"
    echo "📁 Web root: /var/www/html"
    echo "🗄️  Database: $DB_NAME"
    echo "🔐 DB User: $DB_USER"
    echo "=================================="
    echo
    log_warning "IMPORTANT: Save these credentials!"
    echo "DB Root Password: $DB_ROOT_PASS"
    echo "DB App Password: $DB_PASS"
    echo
    log_info "🔑 CRITICAL SSH SETUP STEPS:"
    echo "1. 📝 In a NEW terminal, test SSH connection:"
    echo "   ssh $NEW_USER@your-server -p $SSH_PORT"
    echo "   (Password: TempPass123! - if no SSH keys)"
    echo ""
    echo "2. 🔐 After successful login, harden SSH:"
    echo "   ./secure-ssh.sh"
    echo ""
    echo "3. 🌐 Configure your domain DNS to point here"
    echo "4. 📦 Use deploy script: ./deploy.sh <repo> <name>"
    echo ""
    log_warning "⚠️  SSH is currently on BOTH ports 22 and $SSH_PORT for safety"
    log_warning "⚠️  DO NOT close this session until you test the new connection!"
    log_warning "⚠️  Reboot recommended after SSH is properly configured"
}

# Run main function
main "$@"