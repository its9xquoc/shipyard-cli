#!/bin/bash
set -e

# ===================================================================
# UNIVERSAL SITE DELETE SCRIPT
# ===================================================================

log_info() { echo -e "\e[34m[INFO]\e[0m $*"; }
log_success() { echo -e "\e[32m[SUCCESS]\e[0m $*"; }

# 1. Stop Node.js processes if they exist
if pm2 list | grep -q "${APP_NAME}"; then
    log_info "Stopping PM2 process for ${APP_NAME}..."
    sudo pm2 delete "${APP_NAME}" || true
    sudo pm2 save
    log_success "PM2 process stopped."
fi

# 2. Remove Nginx configuration
log_info "Removing Nginx configuration for ${APP_NAME}..."
sudo rm -f "/etc/nginx/sites-enabled/${APP_NAME}.conf"
sudo rm -f "/etc/nginx/sites-available/${APP_NAME}.conf"
sudo nginx -t && sudo systemctl reload nginx
log_success "Nginx configuration removed."

# 3. Remove PHP-FPM pool if it exists
PHP_POOL="/etc/php/${PHP_VERSION:-8.4}/fpm/pool.d/${APP_NAME}.conf"
if [[ -f "${PHP_POOL}" ]]; then
    log_info "Removing PHP-FPM pool: ${PHP_POOL}..."
    sudo rm -f "${PHP_POOL}"
    sudo systemctl reload "php${PHP_VERSION:-8.4}-fpm"
    log_success "PHP-FPM pool removed."
fi

log_success "Site resources cleaned up from system (Nginx/PHP/PM2)."
log_info "Note: Application files (${APP_PATH}) and Database were NOT deleted for safety."
