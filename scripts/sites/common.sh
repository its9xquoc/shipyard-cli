#!/bin/bash
set -e

# ===================================================================
# COMMON SITE HELPERS
# ===================================================================

log_info() { echo -e "\e[34m[INFO]\e[0m $*"; }
log_success() { echo -e "\e[32m[SUCCESS]\e[0m $*"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $*"; }

# 1. Generic Database Creation
create_database() {
    log_info "Creating database: ${DB_NAME}..."
    sudo mysql -u"${DB_ROOT_USER}" -p"${DB_ROOT_PASS}" <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
    log_success "Database and user created."
}

# 2. Generic Clone Repository
clone_repository() {
    log_info "Cloning repository: ${GIT_REPO} (Branch: ${GIT_BRANCH:-main})..."
    sudo mkdir -p "${APP_PATH}"
    sudo git clone -b "${GIT_BRANCH:-main}" "${GIT_REPO}" "${APP_PATH}"
    sudo chown -R www-data:www-data "${APP_PATH}"
    log_success "Repository cloned to ${APP_PATH}."
}

# 3. Generic SSL Setup (Certbot)
setup_ssl() {
    if [[ "${DOMAIN}" != "_" ]]; then
        log_info "Setting up SSL for ${DOMAIN}..."
        # Try to obtain certificate for both domain and www subdomain
        sudo certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos -m "${EMAIL:-admin@server.com}" --redirect
        log_success "SSL enabled for ${DOMAIN}."
    else
        log_error "Domain is '_', skipping SSL."
    fi
}

# 4. Cleanup site-add execution
site_add_done() {
    sudo chown -R www-data:www-data "${APP_PATH}"
    log_success "Permissions fixed. Setup complete!"
}
