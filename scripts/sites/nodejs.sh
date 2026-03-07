#!/bin/bash
set -e

# ===================================================================
# NODE.JS SPECIFIC LOGIC (Reverse Proxy)
# ===================================================================

# 1. Node.js Dependency Installation
nodejs_install_dependencies() {
    log_info "Installing Node.js dependencies..."
    cd "${APP_PATH}"
    sudo -u www-data npm install --production
    log_success "Node.js dependencies installed."
}

# 2. Node.js Build
nodejs_build() {
    log_info "Building Node.js app..."
    cd "${APP_PATH}"
    sudo -u www-data npm run build || log_error "Build failed."
    log_success "Node.js build completed."
}

# 3. Node.js Startup (PM2)
nodejs_startup_pm2() {
    log_info "Starting Node.js app with PM2..."
    cd "${APP_PATH}"
    sudo -u www-data pm2 start npm --name "${APP_NAME}" -- start || sudo -u www-data pm2 restart "${APP_NAME}"
    sudo -u www-data pm2 save
    log_success "Node.js app started with PM2."
}

# 4. Node.js Nginx Configuration (Reverse Proxy)
nodejs_configure_nginx() {
    local nginx_conf="/etc/nginx/sites-available/${APP_NAME}.conf"
    local proxy_port="${NODE_PORT:-3000}"
    
    log_info "Configuring Nginx Reverse Proxy for ${DOMAIN} (Port ${proxy_port})..."
    sudo tee "${nginx_conf}" >/dev/null <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    access_log /var/log/nginx/${APP_NAME}_access.log;
    error_log  /var/log/nginx/${APP_NAME}_error.log;

    location / {
        proxy_pass http://127.0.0.1:${proxy_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    sudo ln -sf "${nginx_conf}" "/etc/nginx/sites-enabled/${APP_NAME}.conf"
    sudo nginx -t && sudo systemctl reload nginx
    log_success "Nginx Reverse Proxy configured."
}
