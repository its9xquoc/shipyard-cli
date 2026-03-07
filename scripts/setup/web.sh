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
