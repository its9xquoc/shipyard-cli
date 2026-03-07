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
NEW_USER="${NEW_USER:-deploy}"
NEW_USER_PASSWORD="${NEW_USER_PASSWORD:-TempPass123!}"

# SSH Configuration
SSH_PORT="${SSH_PORT:-2222}"
SSH_KEY_TYPE="ed25519"  # More secure than rsa

# Domain & SSL Configuration
DOMAIN="${DOMAIN:-_}"
EMAIL="${EMAIL:-your-email@domain.com}"

# Database Configuration
DB_ROOT_PASS="${DB_ROOT_PASS:-$(openssl rand -base64 32)}"
DB_NAME="${DB_NAME:-app_db}"
DB_USER="${DB_USER:-app_user}"
DB_PASS="${DB_PASS:-$(openssl rand -base64 24)}"

# Redis Configuration
REDIS_PASS="${REDIS_PASS:-$(openssl rand -base64 24)}"

# PHP Configuration
PHP_VERSION="${PHP_VERSION:-8.4}"

# Node.js Configuration
NODE_VERSION="${NODE_VERSION:-20}"  # LTS version

# Paths
WEB_ROOT="${WEB_ROOT:-/var/www}"
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
