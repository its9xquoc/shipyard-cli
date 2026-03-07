
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
