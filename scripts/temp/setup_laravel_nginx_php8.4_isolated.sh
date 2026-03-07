#!/bin/bash
set -e

# ===============================
# CONFIG SECTION
# ===============================
APP_NAME="laravel_app"
APP_PATH="/var/www/$APP_NAME"
GIT_REPO="https://github.com/laravel/laravel.git"
DOMAIN="_"   # đổi thành domain thật nếu có
PHP_VERSION="8.4"

DB_ROOT_USER="root"
DB_ROOT_PASS="4Itxx17QvRsa"

DB_NAME="laravel_db"
DB_USER="laravel_user"
DB_PASS="StrongP@ssw0rd"

# ===============================
# 1. Update & dependencies
# ===============================
echo "[1/9] Updating system..."
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y software-properties-common ca-certificates lsb-release apt-transport-https curl git unzip nginx zip

# ===============================
# 2. Add PHP repo & install PHP 8.4
# ===============================
echo "[2/9] Adding Ondrej PHP repository..."
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update -y

echo "[2.1] Installing PHP ${PHP_VERSION}..."
sudo apt install -y php${PHP_VERSION} php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-curl php${PHP_VERSION}-zip php${PHP_VERSION}-intl

systemctl enable php${PHP_VERSION}-fpm
systemctl start php${PHP_VERSION}-fpm

# ===============================
# 3. Install Composer
# ===============================
echo "[3/9] Installing Composer..."
if ! command -v composer &> /dev/null; then
    curl -sS https://getcomposer.org/installer -o composer-setup.php
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    rm composer-setup.php
fi

# ===============================
# 4. Setup MariaDB
# ===============================
echo "[4/9] Installing and configuring MariaDB..."
sudo apt install -y mariadb-server mariadb-client
sudo systemctl enable mariadb
sudo systemctl start mariadb

sudo mysql -u${DB_ROOT_USER} -p${DB_ROOT_PASS} -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -u${DB_ROOT_USER} -p${DB_ROOT_PASS} -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
sudo mysql -u${DB_ROOT_USER} -p${DB_ROOT_PASS} -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
sudo mysql -u${DB_ROOT_USER} -p${DB_ROOT_PASS} -e "FLUSH PRIVILEGES;"

# ===============================
# 5. Clone & setup Laravel
# ===============================
echo "[5/9] Cloning Laravel source..."
sudo mkdir -p ${APP_PATH}
sudo git clone ${GIT_REPO} ${APP_PATH}
cd ${APP_PATH}

echo "[5.1] Installing dependencies..."
sudo composer install --no-interaction --prefer-dist --optimize-autoloader

echo "[5.2] Configuring environment..."
sudo cp .env.example .env
sudo sed -i "s/DB_CONNECTION=.*/DB_CONNECTION=mysql/" .env
sudo sed -i "s/# DB_HOST=.*/DB_HOST=127.0.0.1/" .env
sudo sed -i "s/# DB_PORT=.*/DB_PORT=3306/" .env
sudo sed -i "s/# DB_DATABASE=.*/DB_DATABASE=${DB_NAME}/" .env
sudo sed -i "s/# DB_USERNAME=.*/DB_USERNAME=${DB_USER}/" .env
sudo sed -i "s/# DB_PASSWORD=.*/DB_PASSWORD=${DB_PASS}/" .env

sudo php artisan key:generate
sudo php artisan migrate --force || true

# ===============================
# 6. Create PHP-FPM pool for app
# ===============================
POOL_FILE="/etc/php/${PHP_VERSION}/fpm/pool.d/${APP_NAME}.conf"
SOCK_PATH="/run/php/php${PHP_VERSION}-fpm-${APP_NAME}.sock"

echo "[6/9] Creating PHP-FPM pool for ${APP_NAME}..."
sudo tee ${POOL_FILE} >/dev/null <<EOF
[${APP_NAME}]
user = www-data
group = www-data
listen = ${SOCK_PATH}
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
php_admin_value[max_execution_time] = 300
chdir = /
EOF

sudo systemctl reload php${PHP_VERSION}-fpm
sleep 2

# ===============================
# 7. Configure nginx
# ===============================
echo "[7/9] Configuring nginx..."
NGINX_CONF="/etc/nginx/sites-available/${APP_NAME}.conf"

sudo tee ${NGINX_CONF} >/dev/null <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    root ${APP_PATH}/public;

    index index.php index.html;
    charset utf-8;

    access_log /var/log/nginx/${APP_NAME}_access.log;
    error_log  /var/log/nginx/${APP_NAME}_error.log;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${SOCK_PATH};
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -sf ${NGINX_CONF} /etc/nginx/sites-enabled/${APP_NAME}.conf
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl reload nginx

# ===============================
# 8. Permissions & optimize
# ===============================
echo "[8/9] Setting permissions and optimizing..."
sudo chown -R www-data:www-data ${APP_PATH}
sudo chmod -R 775 ${APP_PATH}/storage ${APP_PATH}/bootstrap/cache

sudo php artisan config:cache
sudo php artisan route:cache
sudo php artisan view:cache

# ===============================
# 9. Done
# ===============================
echo "✅ Laravel + MariaDB setup complete!"
echo "------------------------------------------"
echo "URL: http://${DOMAIN}"
echo "App path : ${APP_PATH}"
echo "PHP-FPM  : ${SOCK_PATH}"
echo "Pool file: ${POOL_FILE}"
echo "Database : ${DB_NAME}"
echo "User     : ${DB_USER}"
echo "Password : ${DB_PASS}"
echo "------------------------------------------"
