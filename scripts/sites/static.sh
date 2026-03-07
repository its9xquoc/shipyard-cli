#!/bin/bash
set -e

# ===================================================================
# STATIC SITE SPECIFIC LOGIC
# ===================================================================

# 1. Static Nginx Configuration
static_configure_nginx() {
    local nginx_conf="/etc/nginx/sites-available/${APP_NAME}.conf"
    
    log_info "Configuring Nginx for Static HTML/JS: ${DOMAIN}..."
    sudo tee "${nginx_conf}" >/dev/null <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    root ${APP_PATH};

    index index.html index.htm;
    charset utf-8;

    access_log /var/log/nginx/${APP_NAME}_access.log;
    error_log  /var/log/nginx/${APP_NAME}_error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
    sudo ln -sf "${nginx_conf}" "/etc/nginx/sites-enabled/${APP_NAME}.conf"
    sudo nginx -t && sudo systemctl reload nginx
    log_success "Nginx Static Site configured."
}
