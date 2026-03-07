#!/bin/bash
set -e

# ===================================================================
# LARAVEL SPECIFIC LOGIC
# ===================================================================

# 1. Laravel Dependency Installation
laravel_install_dependencies() {
    log_info "Installing composer dependencies..."
    cd "${APP_PATH}"
    sudo -u www-data composer install --no-interaction --prefer-dist --optimize-autoloader
    log_success "Dependencies installed."
}

# 2. Laravel Environment Configuration
laravel_configure_env() {
    log_info "Configuring .env file for Laravel..."
    cd "${APP_PATH}"
    if [ ! -f .env ]; then
        sudo -u www-data cp .env.example .env
    fi
    sudo sed -i "s/DB_CONNECTION=.*/DB_CONNECTION=mysql/" .env
    sudo sed -i "s/DB_HOST=.*/DB_HOST=127.0.0.1/" .env
    sudo sed -i "s/DB_DATABASE=.*/DB_DATABASE=${DB_NAME}/" .env
    sudo sed -i "s/DB_USERNAME=.*/DB_USERNAME=${DB_USER}/" .env
    sudo sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${DB_PASS}/" .env
    
    if grep -q "APP_KEY=$" .env || ! grep -q "APP_KEY=" .env; then
        sudo -u www-data php artisan key:generate --force
    fi
    log_success ".env configured and key generated."
}

# 3. Laravel Migration
laravel_run_migrations() {
    log_info "Running migrations for Laravel..."
    cd "${APP_PATH}"
    sudo -u www-data php artisan migrate --force
    log_success "Migrations completed."
}

# 4. Laravel PHP-FPM Pool
laravel_setup_php_fpm_pool() {
    local pool_file="/etc/php/${PHP_VERSION}/fpm/pool.d/${APP_NAME}.conf"
    local sock_path="/run/php/php${PHP_VERSION}-fpm-${APP_NAME}.sock"
    
    log_info "Creating PHP-FPM pool for ${APP_NAME}..."
    sudo tee "${pool_file}" >/dev/null <<EOF
[${APP_NAME}]
user = www-data
group = www-data
listen = ${sock_path}
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 2
pm.max_spare_servers = 5
php_admin_value[upload_max_filesize] = 64M
php_admin_value[post_max_size] = 64M
php_admin_value[memory_limit] = 512M
chdir = /
EOF
    sudo systemctl reload "php${PHP_VERSION}-fpm"
    log_success "PHP-FPM pool created."
}

# 5. Laravel Nginx Configuration
laravel_configure_nginx() {
    local nginx_conf="/etc/nginx/sites-available/${APP_NAME}.conf"
    local sock_path="/run/php/php${PHP_VERSION}-fpm-${APP_NAME}.sock"
    
    log_info "Configuring Nginx for Laravel: ${DOMAIN}..."
    sudo tee "${nginx_conf}" >/dev/null <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    root ${APP_PATH}/public;

    index index.php index.html;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${sock_path};
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
    sudo ln -sf "${nginx_conf}" "/etc/nginx/sites-enabled/${APP_NAME}.conf"
    sudo nginx -t && sudo systemctl reload nginx
    log_success "Nginx configured for Laravel."
}

# 6. Laravel Cleanup execution
laravel_finalize() {
    sudo chown -R www-data:www-data "${APP_PATH}"
    sudo chmod -R 775 "${APP_PATH}/storage" "${APP_PATH}/bootstrap/cache"
    log_success "Laravel final permissions set."
}
