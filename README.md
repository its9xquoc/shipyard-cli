# 🛳️ Shipyard CLI

**Shipyard CLI** is a premium, developer-centric command-line tool designed for **Senior DevOps and Laravel Engineers**. It provides a robust, modular, and isolated environment for managing VPS servers and deploying various types of web applications with ease.

Built on top of **Laravel Zero**, it brings the power of Artisan commands to server orchestration.

---

## 🚀 Key Highlights

- **Senior VPS Provisioning**: Transform fresh Ubuntu instances into hardened, optimized web servers in minutes.
- **Isolated Application Hosting**: Each site gets its own PHP-FPM pool or PM2 process, ensuring maximum security and performance.
- **Multi-Platform Support**: Expertly handle **Laravel**, **WordPress**, **Node.js/Next.js**, and **Static** applications.
- **Smart Orchestration**: Remembers your active server to streamline repetitive tasks.
- **Zero-Footprint Execution**: Commands are pushed via SSH piped scripts, leaving no temporary files on your production servers.

---

## 🛠️ Performance & Security

- **Hardened SSH**: Custom ports, disabled root login, and enforced key-based authentication.
- **Optimized Stack**: Pre-configured Nginx, PHP (8.1 - 8.4), MariaDB, Redis, and Fail2Ban.
- **Modular Design**: Choose exactly which parts of the stack to install or update.

---

## 📦 Installation

```bash
git clone https://github.com/its9xquoc/shipyard-cli.git
cd shipyard-cli
composer install
```

Make sure you have a `storage/servers.yaml` file (automatically created on first run) to store your server configurations locally.

---

## 📖 Complete Documentation

The CLI is packed with features. For a detailed guide on every command, please refer to:

👉 **[USE_GUIDE.md](./USE_GUIDE.md)**

### Quick Commands Overview:

| Category | Commands |
| :--- | :--- |
| **Server** | `setup`, `server:add`, `server:switch`, `server:current` |
| **Sites** | `site:add`, `site:list`, `site:delete`, `site:logs` |
| **Resources** | `nginx:restart`, `php:status`, `database:shell`, `daemon:list` |
| **DevOps** | `deploy`, `tinker`, `ssh:configure`, `env:pull` |

---

## 🤝 Contributing & Development

We value clean code and consistency.

- **Coding Style**: The project follows PSR-12/Laravel standards via **Laravel Pint**.
- **Linting**: Run `./vendor/bin/pint` before committing.
- **Modularity**: New scripts should be added to `scripts/setup/` or `scripts/sites/`.

---

## 📄 License

The Shipyard CLI is open-sourced software licensed under the [MIT license](LICENSE).
