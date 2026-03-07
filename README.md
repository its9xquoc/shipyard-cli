# Shipyard CLI

A powerful command-line interface for managing your VPS servers and SSH connections, built on Laravel.

## Features

- **Server Management**: Add, list, edit, and delete VPS server configurations.
- **SSH Checks**: Instantly test SSH connectivity to your configured servers.
- **Interactive Prompts**: A premium CLI experience using Laravel Prompts.
- **YAML Storage**: All server data is securely stored in local YAML format.

## Installation

```bash
composer global require its9xquoc/shipyard-cli
```

Or clone the repository and run:

```bash
composer install
```

## Usage

The CLI provides several commands to manage your servers:

### List Servers
Display all configured VPS servers in a clean table format.
```bash
php shipyard server:list
```

### Add a Server
Interactively add a new VPS server configuration.
```bash
php shipyard server:add
```

### Edit a Server
Update an existing server's details.
```bash
php shipyard server:edit
```

### Delete a Server
Remove a server configuration.
```bash
php shipyard server:delete
```

### Test SSH Connection
Test if the CLI can connect to the server using the provided credentials.
```bash
php shipyard ssh:test
```

## Development

### Setup Pre-commit Hook
To ensure code style consistency, run the setup script:
```bash
bash scripts/setup-recommit.sh
```

### Linting
Run Laravel Pint to format the code:
```bash
./vendor/bin/pint
```

## License

MIT License. Please see [LICENSE](LICENSE) for more information.
