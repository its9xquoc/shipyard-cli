#!/bin/bash

# ===================================================================
# VPS SETUP AUTOMATION SCRIPT
# ===================================================================
# Description: Complete Ubuntu/Debian VPS setup from scratch
# Components: Security, Firewall, Nginx, PHP, MariaDB, Node.js, Redis, SSL
# Author: System Administrator
# Version: 2.0
# Last Updated: 2025-12-31
# ===================================================================

set -euo pipefail  # Exit on error, undefined variables, and pipe failures
IFS=$'\n\t'        # Set Internal Field Separator for better word splitting

# ===================================================================
# CONFIGURATION SECTION
# ===================================================================
# ⚠️  IMPORTANT: Update these values before running the script
# ===================================================================

# User Configuration
readonly NEW_USER="${NEW_USER:-deploy}"
readonly NEW_USER_PASSWORD="${NEW_USER_PASSWORD:-TempPass123!}"

# SSH Configuration
readonly SSH_PORT="${SSH_PORT:-2222}"
readonly SSH_KEY_TYPE="ed25519"  # More secure than rsa

# Domain & SSL Configuration
readonly DOMAIN="${DOMAIN:-_}"
readonly EMAIL="${EMAIL:-your-email@domain.com}"

# Database Configuration
readonly DB_ROOT_PASS="${DB_ROOT_PASS:-$(openssl rand -base64 32)}"
readonly DB_NAME="${DB_NAME:-app_db}"
readonly DB_USER="${DB_USER:-app_user}"
readonly DB_PASS="${DB_PASS:-$(openssl rand -base64 24)}"

# Redis Configuration
readonly REDIS_PASS="$(openssl rand -base64 24)"

# PHP Configuration
readonly PHP_VERSION="8.4"

# Node.js Configuration
readonly NODE_VERSION="20"  # LTS version

# Paths
readonly WEB_ROOT="/var/www"
readonly LOG_FILE="/var/log/vps-setup.log"
readonly BACKUP_DIR="/root/backup-$(date +%Y%m%d-%H%M%S)"

# ===================================================================
# COLOR DEFINITIONS
# ===================================================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'  # No Color

# ===================================================================
# LOGGING FUNCTIONS
# ===================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*" | tee -a "$LOG_FILE" >&2
}

log_header() {
    echo -e "\n${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}$*${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}\n"
}

# ===================================================================
# UTILITY FUNCTIONS
# ===================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        log_info "Please run: sudo $0"
        exit 1
    fi
}

check_os() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine OS version"
        exit 1
    fi
    
    source /etc/os-release
    
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        log_error "This script only supports Ubuntu and Debian"
        exit 1
    fi
    
    log_info "Detected: $PRETTY_NAME"
}

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${BACKUP_DIR}/$(basename "$file").backup"
        mkdir -p "$BACKUP_DIR"
        cp "$file" "$backup"
        log_info "Backed up: $file → $backup"
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

service_is_running() {
    systemctl is-active --quiet "$1"
}

prompt_continue() {
    local message="${1:-Continue?}"
    echo -e "\n${YELLOW}${message}${NC}"
    read -rp "Type 'yes' to continue: " response
    if [[ "$response" != "yes" ]]; then
        log_warning "Operation cancelled by user"
        exit 0
    fi
}

generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# ===================================================================
# SYSTEM PREPARATION
# ===================================================================

update_system() {
    log_header "UPDATING SYSTEM PACKAGES"
    
    log_info "Updating package lists..."
    apt-get update -y
    
    log_info "Upgrading installed packages..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    
    log_info "Installing essential packages..."
    apt-get install -y \
        curl wget git unzip zip \
        software-properties-common \
        ca-certificates lsb-release \
        apt-transport-https gnupg2 \
        build-essential \
        ufw fail2ban \
        htop iotop nethogs \
        nano vim tree \
        net-tools dnsutils \
        acl attr \
        openssl
    
    log_success "System packages updated"
}

setup_timezone() {
    log_header "CONFIGURING TIMEZONE"
    
    timedatectl set-timezone UTC
    log_success "Timezone set to UTC"
}

# ===================================================================
# USER MANAGEMENT
# ===================================================================

create_user() {
    log_header "CREATING NON-ROOT USER"
    
    if id "$NEW_USER" &>/dev/null; then
        log_warning "User $NEW_USER already exists"
        return 0
    fi
    
    log_info "Creating user: $NEW_USER"
    useradd -m -s /bin/bash -G sudo,www-data "$NEW_USER"
    
    echo "$NEW_USER:$NEW_USER_PASSWORD" | chpasswd
    
    # Force password change on first login
    chage -d 0 "$NEW_USER"
    
    log_success "User $NEW_USER created with temporary password"
}

setup_ssh_keys() {
    log_header "SETTING UP SSH KEYS"
    
    local user_ssh_dir="/home/$NEW_USER/.ssh"
    
    # Create .ssh directory for new user
    mkdir -p "$user_ssh_dir"
    chmod 700 "$user_ssh_dir"
    
    # Copy SSH keys from root if they exist
    if [[ -f /root/.ssh/authorized_keys ]]; then
        cp /root/.ssh/authorized_keys "$user_ssh_dir/"
        chmod 600 "$user_ssh_dir/authorized_keys"
        chown -R "$NEW_USER:$NEW_USER" "$user_ssh_dir"
        log_success "SSH keys copied from root to $NEW_USER"
    else
        log_warning "No SSH keys found in /root/.ssh/"
        log_warning "Please add your SSH public key manually:"
        log_info "  echo 'your-public-key' >> $user_ssh_dir/authorized_keys"
    fi
}

# ===================================================================
# SSH HARDENING
# ===================================================================

configure_ssh() {
    log_header "CONFIGURING SSH SECURITY"
    
    backup_file "/etc/ssh/sshd_config"
    
    log_info "Configuring SSH on port $SSH_PORT (keeping port 22 temporarily)"
    
    cat > /etc/ssh/sshd_config <<EOF
# ===================================================================
# SSH Server Configuration - Security Hardened
# Generated by VPS Setup Script on $(date)
# ===================================================================

# Network
Port 22
Port $SSH_PORT
AddressFamily inet
ListenAddress 0.0.0.0

# Protocol
Protocol 2

# Host Keys
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Ciphers and Algorithms (Modern, Secure)
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512

# Authentication
LoginGraceTime 60
PermitRootLogin yes
StrictModes yes
MaxAuthTries 3
MaxSessions 5
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Security Features
IgnoreRhosts yes
HostbasedAuthentication no
PermitUserEnvironment no
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
PermitTunnel no
Banner none

# Connection Management
ClientAliveInterval 300
ClientAliveCountMax 2
MaxStartups 10:30:60

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Subsystems
Subsystem sftp /usr/lib/openssh/sftp-server -f AUTHPRIV -l INFO

# Override for specific users (if needed)
Match User $NEW_USER
    PasswordAuthentication yes
EOF

    # Test SSH configuration
    if sshd -t; then
        systemctl reload ssh
        log_success "SSH configured successfully"
        log_warning "SSH is listening on BOTH port 22 and $SSH_PORT for safety"
    else
        log_error "SSH configuration test failed!"
        log_info "Restoring backup..."
        cp "${BACKUP_DIR}/sshd_config.backup" /etc/ssh/sshd_config
        systemctl reload ssh
        exit 1
    fi
}

create_ssh_hardening_script() {
    log_info "Creating SSH hardening script..."
    
    cat > "/home/$NEW_USER/harden-ssh.sh" <<'EOFSCRIPT'
#!/bin/bash
# SSH Hardening Script - Run after testing SSH connection

set -e

echo "╔════════════════════════════════════════════════════════╗"
echo "║         SSH HARDENING - FINAL LOCKDOWN                 ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "This will:"
echo "  • Disable root login"
echo "  • Disable password authentication"
echo "  • Remove port 22 (keep only custom port)"
echo ""
echo "⚠️  WARNING: This may lock you out if:"
echo "  • SSH keys are not properly configured"
echo "  • Custom port is blocked by firewall"
echo "  • You haven't tested the new configuration"
echo ""

read -rp "Have you tested SSH on the new port? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "❌ Cancelled. Test the connection first!"
    exit 1
fi

echo "🔒 Hardening SSH configuration..."

sudo tee /etc/ssh/sshd_config > /dev/null <<'EOFSSH'
Port 2222
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Hardened Authentication
LoginGraceTime 30
PermitRootLogin no
StrictModes yes
MaxAuthTries 2
MaxSessions 2
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Security
IgnoreRhosts yes
HostbasedAuthentication no
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no

# Connection
ClientAliveInterval 300
ClientAliveCountMax 2

Subsystem sftp /usr/lib/openssh/sftp-server
EOFSSH

if sudo sshd -t; then
    sudo systemctl restart ssh
    echo "✅ SSH hardened successfully!"
    echo "📝 Remember: ssh $USER@server -p 2222"
else
    echo "❌ Configuration error! SSH not restarted."
    exit 1
fi
EOFSCRIPT

    chmod +x "/home/$NEW_USER/harden-ssh.sh"
    chown "$NEW_USER:$NEW_USER" "/home/$NEW_USER/harden-ssh.sh"
    
    log_success "Hardening script created: /home/$NEW_USER/harden-ssh.sh"
}

# ===================================================================
# FIREWALL CONFIGURATION
# ===================================================================

setup_firewall() {
    log_header "CONFIGURING UFW FIREWALL"
    
    log_info "Resetting firewall rules..."
    ufw --force reset
    
    log_info "Setting default policies..."
    ufw default deny incoming
    ufw default allow outgoing
    
    log_info "Allowing SSH ports..."
    ufw allow 22/tcp comment 'SSH - Temporary'
    ufw allow "$SSH_PORT/tcp" comment 'SSH - Custom Port'
    
    log_info "Allowing HTTP/HTTPS..."
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    
    log_info "Enabling firewall..."
    ufw --force enable
    
    log_success "Firewall configured and enabled"
    ufw status numbered
}

# ===================================================================
# FAIL2BAN CONFIGURATION
# ===================================================================

setup_fail2ban() {
    log_header "CONFIGURING FAIL2BAN"
    
    backup_file "/etc/fail2ban/jail.local"
    
    cat > /etc/fail2ban/jail.local <<EOF
# ===================================================================
# Fail2Ban Configuration
# Generated by VPS Setup Script on $(date)
# ===================================================================

[DEFAULT]
# Ban settings
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd
destemail = $EMAIL
sendername = Fail2Ban
action = %(action_mwl)s

# Ignore local connections
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = ssh,$SSH_PORT
filter = sshd
logpath = %(sshd_log)s
maxretry = 3
bantime = 7200

[nginx-http-auth]
enabled = true
port = http,https
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3

[nginx-noscript]
enabled = true
port = http,https
filter = nginx-noscript
logpath = /var/log/nginx/access.log
maxretry = 6

[nginx-badbots]
enabled = true
port = http,https
filter = nginx-badbots
logpath = /var/log/nginx/access.log
maxretry = 2

[nginx-noproxy]
enabled = true
port = http,https
filter = nginx-noproxy
logpath = /var/log/nginx/access.log
maxretry = 2

[nginx-limit-req]
enabled = true
port = http,https
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 10
findtime = 300
bantime = 7200
EOF

    systemctl enable fail2ban
    systemctl restart fail2ban
    
    log_success "Fail2Ban configured and started"
}

# ===================================================================
# NGINX INSTALLATION
# ===================================================================

install_nginx() {
    log_header "INSTALLING NGINX WEB SERVER"
    
    if command_exists nginx; then
        log_warning "Nginx already installed"
        return 0
    fi
    
    log_info "Installing Nginx..."
    apt-get install -y nginx
    
    backup_file "/etc/nginx/nginx.conf"
    
    log_info "Configuring Nginx..."
    
    cat > /etc/nginx/nginx.conf <<'EOF'
# ===================================================================
# Nginx Configuration - Optimized & Secure
# ===================================================================

user www-data;
worker_processes auto;
worker_rlimit_nofile 65535;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}

http {
    # ===============================
    # Basic Settings
    # ===============================
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    keepalive_requests 100;
    types_hash_max_size 2048;
    server_tokens off;
    server_names_hash_bucket_size 64;
    client_max_body_size 100M;
    
    # ===============================
    # MIME Types
    # ===============================
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # ===============================
    # SSL Settings
    # ===============================
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # ===============================
    # Security Headers
    # ===============================
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # ===============================
    # Logging
    # ===============================
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    'rt=$request_time uct="$upstream_connect_time" '
                    'uht="$upstream_header_time" urt="$upstream_response_time"';
    
    access_log /var/log/nginx/access.log main buffer=32k flush=5m;
    error_log /var/log/nginx/error.log warn;
    
    # ===============================
    # Gzip Compression
    # ===============================
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
        application/rss+xml
        application/atom+xml
        application/x-javascript
        image/svg+xml
        text/x-component
        text/x-cross-domain-policy;
    gzip_disable "msie6";
    
    # ===============================
    # Rate Limiting
    # ===============================
    limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
    limit_req_zone $binary_remote_addr zone=api:10m rate=30r/m;
    limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
    limit_conn_zone $binary_remote_addr zone=conn_limit:10m;
    
    # ===============================
    # Buffers & Timeouts
    # ===============================
    client_body_buffer_size 128k;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 16k;
    client_body_timeout 12;
    client_header_timeout 12;
    send_timeout 10;
    
    # ===============================
    # File Cache
    # ===============================
    open_file_cache max=10000 inactive=20s;
    open_file_cache_valid 30s;
    open_file_cache_min_uses 2;
    open_file_cache_errors on;
    
    # ===============================
    # Include Additional Configs
    # ===============================
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

    # Remove default site
    rm -f /etc/nginx/sites-enabled/default
    
    # Test configuration
    if nginx -t; then
        systemctl enable nginx
        systemctl start nginx
        log_success "Nginx installed and configured"
    else
        log_error "Nginx configuration test failed"
        exit 1
    fi
}

# ===================================================================
# PHP INSTALLATION
# ===================================================================

install_php() {
    log_header "INSTALLING PHP $PHP_VERSION"
    
    log_info "Adding Ondrej PHP repository..."
    add-apt-repository ppa:ondrej/php -y
    apt-get update -y
    
    log_info "Installing PHP and extensions..."
    apt-get install -y \
        php${PHP_VERSION} \
        php${PHP_VERSION}-fpm \
        php${PHP_VERSION}-cli \
        php${PHP_VERSION}-common \
        php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-bcmath \
        php${PHP_VERSION}-curl \
        php${PHP_VERSION}-zip \
        php${PHP_VERSION}-intl \
        php${PHP_VERSION}-gd \
        php${PHP_VERSION}-redis \
        php${PHP_VERSION}-imagick \
        php${PHP_VERSION}-opcache \
        php${PHP_VERSION}-soap \
        php${PHP_VERSION}-readline
    
    log_info "Configuring PHP-FPM..."
    
    local php_ini="/etc/php/${PHP_VERSION}/fpm/php.ini"
    local fpm_pool="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"
    
    backup_file "$php_ini"
    backup_file "$fpm_pool"
    
    # PHP-FPM optimizations
    sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 100M/' "$php_ini"
    sed -i 's/^post_max_size = .*/post_max_size = 100M/' "$php_ini"
    sed -i 's/^memory_limit = .*/memory_limit = 512M/' "$php_ini"
    sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "$php_ini"
    sed -i 's/^max_input_time = .*/max_input_time = 300/' "$php_ini"
    sed -i 's/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' "$php_ini"
    sed -i 's/^;opcache.enable=.*/opcache.enable=1/' "$php_ini"
    sed -i 's/^;opcache.memory_consumption=.*/opcache.memory_consumption=128/' "$php_ini"
    
    # PHP-FPM pool configuration
    sed -i 's/^pm = .*/pm = dynamic/' "$fpm_pool"
    sed -i 's/^pm.max_children = .*/pm.max_children = 50/' "$fpm_pool"
    sed -i 's/^pm.start_servers = .*/pm.start_servers = 5/' "$fpm_pool"
    sed -i 's/^pm.min_spare_servers = .*/pm.min_spare_servers = 5/' "$fpm_pool"
    sed -i 's/^pm.max_spare_servers = .*/pm.max_spare_servers = 10/' "$fpm_pool"
    
    systemctl enable php${PHP_VERSION}-fpm
    systemctl start php${PHP_VERSION}-fpm
    
    log_success "PHP $PHP_VERSION installed and configured"
}

# ===================================================================
# COMPOSER INSTALLATION
# ===================================================================

install_composer() {
    log_header "INSTALLING COMPOSER"
    
    if command_exists composer; then
        log_warning "Composer already installed"
        composer self-update
        return 0
    fi
    
    log_info "Downloading Composer installer..."
    EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

    if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
        log_error "Invalid installer checksum"
        rm composer-setup.php
        exit 1
    fi

    php composer-setup.php --install-dir=/usr/local/bin --filename=composer --quiet
    rm composer-setup.php
    
    chmod +x /usr/local/bin/composer
    
    log_success "Composer installed successfully"
    composer --version
}

# ===================================================================
# NODE.JS INSTALLATION
# ===================================================================

install_nodejs() {
    log_header "INSTALLING NODE.JS $NODE_VERSION LTS"
    
    if command_exists node; then
        log_warning "Node.js already installed"
        node --version
        return 0
    fi
    
    log_info "Adding NodeSource repository..."
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
    
    log_info "Installing Node.js..."
    apt-get install -y nodejs
    
    log_info "Installing global packages..."
    npm install -g npm@latest
    npm install -g pm2 yarn pnpm
    
    # PM2 startup
    pm2 startup systemd -u "$NEW_USER" --hp "/home/$NEW_USER"
    
    log_success "Node.js installed"
    node --version
    npm --version
}

# ===================================================================
# MARIADB INSTALLATION
# ===================================================================

install_mariadb() {
    log_header "INSTALLING MARIADB"
    
    if command_exists mysql; then
        log_warning "MariaDB/MySQL already installed"
        return 0
    fi
    
    log_info "Installing MariaDB server..."
    apt-get install -y mariadb-server mariadb-client
    
    systemctl enable mariadb
    systemctl start mariadb
    
    log_info "Securing MariaDB installation..."
    
    # Secure installation
    mysql --user=root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

    log_info "Creating application database..."
    
    mysql -u root -p"${DB_ROOT_PASS}" <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` 
    CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' 
    IDENTIFIED BY '${DB_PASS}';

GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* 
    TO '${DB_USER}'@'localhost';

FLUSH PRIVILEGES;
EOF

    # Optimize MariaDB configuration
    cat > /etc/mysql/mariadb.conf.d/99-custom.cnf <<EOF
[mysqld]
# Custom optimization settings
max_connections = 150
connect_timeout = 5
wait_timeout = 600
max_allowed_packet = 64M
thread_cache_size = 128
sort_buffer_size = 4M
bulk_insert_buffer_size = 16M
tmp_table_size = 32M
max_heap_table_size = 32M

# InnoDB settings
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
innodb_file_per_table = 1
innodb_flush_method = O_DIRECT
innodb_flush_log_at_trx_commit = 2

# Query cache (if supported)
query_cache_size = 0
query_cache_type = 0

# Logging
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow-query.log
long_query_time = 2
EOF

    systemctl restart mariadb
    
    # Test connection
    if mysql -u root -p"${DB_ROOT_PASS}" -e "SELECT 1;" >/dev/null 2>&1; then
        log_success "MariaDB installed and secured"
    else
        log_error "MariaDB connection test failed"
        exit 1
    fi
}

# ===================================================================
# REDIS INSTALLATION
# ===================================================================

install_redis() {
    log_header "INSTALLING REDIS"
    
    if command_exists redis-server; then
        log_warning "Redis already installed"
        return 0
    fi
    
    log_info "Installing Redis..."
    apt-get install -y redis-server
    
    backup_file "/etc/redis/redis.conf"
    
    log_info "Configuring Redis..."
    
    # Secure Redis configuration
    sed -i "s/^# requirepass .*/requirepass ${REDIS_PASS}/" /etc/redis/redis.conf
    sed -i 's/^bind .*/bind 127.0.0.1/' /etc/redis/redis.conf
    sed -i 's/^# maxmemory .*/maxmemory 256mb/' /etc/redis/redis.conf
    sed -i 's/^# maxmemory-policy .*/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf
    sed -i 's/^supervised no/supervised systemd/' /etc/redis/redis.conf
    
    systemctl enable redis-server
    systemctl restart redis-server
    
    log_success "Redis installed and configured"
}

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

# ===================================================================
# MAIN EXECUTION
# ===================================================================

main() {
    # Initialize log file
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    
    log_header "VPS SETUP SCRIPT v2.0"
    
    # Pre-flight checks
    check_root
    check_os
    
    log_info "This script will install and configure:"
    echo "  • Security hardening (SSH, Firewall, Fail2Ban)"
    echo "  • Nginx web server"
    echo "  • PHP ${PHP_VERSION} with extensions"
    echo "  • MariaDB database"
    echo "  • Redis cache"
    echo "  • Node.js ${NODE_VERSION} & PM2"
    echo "  • SSL certificates (optional)"
    echo ""
    
    prompt_continue "Ready to start VPS setup?"
    
    # Execute setup phases
    log_info "Starting VPS setup process..."
    
    update_system
    setup_timezone
    create_user
    setup_ssh_keys
    configure_ssh
    create_ssh_hardening_script
    setup_firewall
    setup_fail2ban
    install_nginx
    install_php
    install_composer
    install_nodejs
    install_mariadb
    install_redis
    create_default_site
    optimize_system
    create_deployment_scripts
    
    # Optional: SSL setup
    if [[ "$DOMAIN" != "_" && "$DOMAIN" != "your-domain.com" ]]; then
        setup_ssl
    fi
    
    # Save credentials and print summary
    save_credentials
    print_summary
    
    log_success "VPS setup completed successfully!"
}

# Execute main function
main "$@"
