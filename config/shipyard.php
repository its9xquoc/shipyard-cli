<?php

return [
    // env('HOME') . '/.shipyard/servers.yaml'
    'storage_path' => storage_path('app/shipyard.yaml'),

    'setup' => [
        'script_path' => base_path('scripts/setup/dispatcher.sh'),
        'default_config' => [
            'deploy_user' => 'deploy',
            'ssh_port' => '2222',
            'domain' => '_',
            'email' => 'admin@server.com',
            'php_version' => '8.4',
            'db_name' => 'app_db',
            'db_user' => 'app_user',
        ],
        'password_length' => 24,
    ],

    'php_versions' => ['8.1', '8.2', '8.3', '8.4'],

    'node_versions' => ['18', '20', '22', '24'],

    'services' => [
        'setup_basic_security' => [
            'description' => 'Apply basic security hardening measures to the server.',
            'script' => base_path('scripts/services/setup_basic_security.sh'),
        ],
        'configure_ssh' => [
            'description' => 'Configure SSH with custom port and security settings.',
            'script' => base_path('scripts/services/configure_ssh.sh'),
        ],
        'setup_firewall' => [
            'description' => 'Set up UFW firewall with recommended rules.',
            'script' => base_path('scripts/services/setup_firewall.sh'),
        ],
        'install_nginx' => [
            'description' => 'Install and configure Nginx web server.',
            'script' => base_path('scripts/services/install_nginx.sh'),
        ],
        'install_php' => [
            'description' => 'Install specified PHP version with common extensions.',
            'script' => base_path('scripts/services/install_php.sh'),
        ],
        'install_composer' => [
            'description' => 'Install Composer globally.',
            'script' => base_path('scripts/services/install_composer.sh'),
        ],
        'install_nodejs' => [
            'description' => 'Install Node.js and npm.',
            'script' => base_path('scripts/services/install_nodejs.sh'),
        ],
        'install_mariadb' => [
            'description' => 'Install MariaDB database server.',
            'script' => base_path('scripts/services/install_mariadb.sh'),
        ],
        'install_redis' => [
            'description' => 'Install Redis in-memory data store.',
            'script' => base_path('scripts/services/install_redis.sh'),
        ],
        'create_default_site' => [
            'description' => 'Create a default Nginx site configuration.',
            'script' => base_path('scripts/services/create_default_site.sh'),
        ],
        'optimize_system' => [
            'description' => 'Apply system optimizations and cleanup.',
            'script' => base_path('scripts/services/optimize_system.sh'),
        ],
        'setup_ssl' => [
            'description' => 'Set up SSL certificates with Let\'s Encrypt.',
            'script' => base_path('scripts/services/setup_ssl.sh'),
        ],
        'deploy_laravel' => [
            'description' => 'Create a deployment script for the Laravel application.',
            'script' => base_path('scripts/services/deploy_laravel.sh'),
        ],
        'deploy_wordpress' => [
            'description' => 'Create a deployment script for WordPress.',
            'script' => base_path('scripts/services/deploy_wordpress.sh'),
        ],
        'deploy_node' => [
            'description' => 'Create a deployment script for a Node.js application.',
            'script' => base_path('scripts/services/deploy_node.sh'),
        ],
        'deploy_static' => [
            'description' => 'Create a deployment script for a static website.',
            'script' => base_path('scripts/services/deploy_static.sh'),
        ],
        'deploy_custom' => [
            'description' => 'Create a deployment script for a custom application.',
            'script' => base_path('scripts/services/deploy_custom.sh'),
        ],
    ],
];
