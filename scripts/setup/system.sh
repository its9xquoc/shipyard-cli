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
