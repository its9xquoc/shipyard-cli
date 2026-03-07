# Shipyard CLI Documentation

Shipyard CLI is a powerful command-line tool that allows you to manage your VPS servers, provision websites (Laravel, WordPress, Node.js), and control server resources.

## Index
- [Getting Started](#getting-started)
- [Server Management](#server-management)
- [VPS Provisioning (Setup)](#vps-provisioning-setup)
- [Website Management](#website-management)
- [Deployments](#deployments)
- [Resource Control](#resource-control)
- [SSH Utilities](#ssh-utilities)

---

## Getting Started

### Installation
Clone the repository and install dependencies:
```bash
git clone https://github.com/its9xquoc/shipyard-cli.git
cd shipyard-cli
composer install
```

### Active Server Concept
Shipyard CLI tracks your "active" server. Once switched, most commands will automatically target this server without prompting.

---

## Server Management

### List Servers
```bash
php artisan server:list
```

### Add a Server
```bash
php artisan server:add
```

### Switch/Active Server
View the current active server:
```bash
php artisan server:current
```

Switch to another server:
```bash
php artisan server:switch
# or
php artisan server:switch server-name
```

---

## VPS Provisioning (Setup)

The `setup` command transforms a fresh Ubuntu server into a fully-functional web server.

```bash
php artisan setup
```

**Available Steps:**
- System Updates & Optimization
- User Creation & SSH Hardening
- Firewall (UFW) & Fail2Ban
- Nginx, PHP-FPM, MariaDB, Redis, Node.js installation
- Automatic configuration of security and performance tuning

---

## Website Management

### Adding a Site
Supports **Laravel**, **WordPress**, **Node.js/Next.js**, and **Static** sites. Each site is isolated using separate PHP-FPM pools or PM2 processes.

```bash
php artisan site:add
```

### Listing Sites
Lists all websites on the active (or selected) server.
```bash
php artisan site:list
```

### Deleting a Site
Removes Nginx configs, PHP pools, and PM2 processes while keeping data/databases safe.
```bash
php artisan site:delete
```

### Site Logs
View application or web server logs:
```bash
php artisan site:logs
php artisan site:logs --follow
```

---

## Deployments

### Initiate Deployment
Runs the `deploy.sh` script located in the site's root directory.
```bash
php artisan deploy
```

### Review Deployment Logs
```bash
php artisan deploy:logs
```

---

## Resource Control

Manage server services directly from the CLI.

### Nginx
```bash
php artisan nginx:status
php artisan nginx:restart
php artisan nginx:logs
```

### PHP-FPM
```bash
php artisan php:status
php artisan php:restart
php artisan php:logs
```

### Database (MariaDB/MySQL)
```bash
php artisan database:status
php artisan database:restart
php artisan database:shell
```

### Daemons (PM2)
```bash
php artisan daemon:status
php artisan daemon:restart
php artisan daemon:logs
```

---

## SSH Utilities

### Interactive Shell
Open a standard SSH session to the active server:
```bash
php artisan ssh
```

### Test Connection
```bash
php artisan ssh:test
```

### Configure SSH Keys
Automatically adds your local public key to the remote server's `authorized_keys`.
```bash
php artisan ssh:configure --key=~/.ssh/id_rsa.pub
```

### Run Arbitrary Commands
Execute a command in the root or a specific site directory:
```bash
php artisan command --command="php artisan inspire"
```

### Remote Tinker (Laravel only)
```bash
php artisan tinker
```
