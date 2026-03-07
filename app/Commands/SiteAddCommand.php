<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Services\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;

use function Laravel\Prompts\multiselect;
use function Laravel\Prompts\password;
use function Laravel\Prompts\select;
use function Laravel\Prompts\text;

class SiteAddCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'site:add';

    protected $description = 'Add a new Website to a VPS server (Modular & Multi-type)';

    public function __construct(
        protected ServerRepository $repository,
        protected SSHService $sshService
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $server = $this->chooseServer();

        // 1. Choose Site Type
        $siteType = select(
            'Select website type:',
            [
                'laravel' => 'Laravel Framework',
                'wordpress' => 'WordPress (CMS)',
                'nodejs' => 'Node.js / Next.js (Reverse Proxy)',
                'static' => 'Static HTML/JS',
            ],
            default: 'laravel'
        );

        // 2. Application Configuration
        $appName = text('Application Name', placeholder: 'myapp', required: true);
        $domain = text('Domain Name', default: '_', required: true);
        $appPath = text('Installation Path', default: "/var/www/{$appName}", required: true);

        // 3. Define Modular Steps based on Type
        $stepsChoices = $this->getStepsForType($siteType);

        $selectedSteps = multiselect(
            label: "Select modular setup steps for this {$siteType} site:",
            options: $stepsChoices,
            default: array_keys($stepsChoices),
            required: true
        );

        // 4. Detailed Configuration for Selected Steps
        $config = $this->promptForModuleConfig($siteType, $selectedSteps, $server, $appName, $domain);

        // 5. Build and Bundle the Remote Script
        $neededModules = array_unique(['common', $siteType]);
        $fullScript = $this->bundleScripts($neededModules);

        // 6. Execute Remote Command
        $envVars = collect($config)->merge([
            'APP_NAME' => $appName,
            'APP_PATH' => $appPath,
            'DOMAIN' => $domain,
            'SITE_TYPE' => $siteType,
        ])->map(fn ($value, $key) => (string) $key . '=' . escapeshellarg((string) ($value ?? '')))->implode(' ');

        $remoteCommand = "{$envVars} bash -s -- " . implode(' ', $selectedSteps) . ' site_add_done';
        $sshCommand = $this->sshService->buildCommand($server, $remoteCommand);

        $this->components->info("Starting modular setup for '{$appName}' ({$siteType}) on '{$server['name']}'...");

        // Pass script via stdin
        $process = proc_open($sshCommand, [
            0 => ['pipe', 'r'],
            1 => STDOUT,
            2 => STDERR,
        ], $pipes);

        if (is_resource($process)) {
            fwrite($pipes[0], $fullScript);
            fclose($pipes[0]);
            $exitCode = proc_close($process);
        } else {
            $this->error('Failed to execute SSH process.');

            return self::FAILURE;
        }

        if ($exitCode === 0) {
            // Persist site info
            $server['sites'] = $server['sites'] ?? [];
            $server['sites'][] = [
                'name' => $appName,
                'domain' => $domain,
                'type' => $siteType,
                'path' => $appPath,
                'database' => $config['DB_NAME'] ?? 'N/A',
                'created_at' => now()->toIso8601String(),
            ];

            $this->repository->updateServer($server['id'], ['sites' => $server['sites']]);
            $this->components->success("Site '{$appName}' added successfully.");

            return self::SUCCESS;
        }

        $this->error("Setup failed with code {$exitCode}.");

        return self::FAILURE;
    }

    /**
     * Map site types to available modular steps.
     */
    protected function getStepsForType(string $type): array
    {
        $commonSteps = [
            'clone_repository' => 'Clone Git Repository',
            'setup_ssl' => 'Setup SSL (Certbot)',
        ];

        switch ($type) {
            case 'laravel':
                return array_merge([
                    'create_database' => 'Create MariaDB Database',
                    'clone_repository' => 'Clone Git Repository',
                    'laravel_install_dependencies' => 'Run Composer Install',
                    'laravel_configure_env' => 'Setup Laravel .env',
                    'laravel_run_migrations' => 'Run Migrations',
                    'laravel_setup_php_fpm_pool' => 'Create PHP-FPM Pool',
                    'laravel_configure_nginx' => 'Configure Laravel Nginx',
                    'setup_ssl' => 'Setup SSL',
                ]);
            case 'wordpress':
                return [
                    'create_database' => 'Create MariaDB Database',
                    'wordpress_download' => 'Download WordPress Core',
                    'wordpress_configure_db' => 'Configure wp-config.php',
                    'wordpress_configure_nginx' => 'Configure WordPress Nginx',
                    'setup_ssl' => 'Setup SSL',
                ];
            case 'nodejs':
                return [
                    'clone_repository' => 'Clone Git Repository',
                    'nodejs_install_dependencies' => 'Install npm Packages',
                    'nodejs_build' => 'Build Build Assets (npm build)',
                    'nodejs_startup_pm2' => 'Start with PM2',
                    'nodejs_configure_nginx' => 'Configure Nginx Reverse Proxy',
                    'setup_ssl' => 'Setup SSL',
                ];
            case 'static':
                return [
                    'clone_repository' => 'Clone Git Repository',
                    'static_configure_nginx' => 'Configure Static Nginx',
                    'setup_ssl' => 'Setup SSL',
                ];
            default:
                return $commonSteps;
        }
    }

    /**
     * Extra configuration prompts based on selected modules.
     */
    protected function promptForModuleConfig(string $type, array $steps, array $server, $appName, $domain): array
    {
        $config = [];

        if (in_array('clone_repository', $steps)) {
            $config['GIT_REPO'] = text('Git Repository URL', placeholder: 'https://...', required: true);
            $config['GIT_BRANCH'] = text('Branch/Tag', default: 'main', required: true);
        }

        if (array_intersect(['create_database', 'laravel_configure_env'], $steps)) {
            $config['DB_NAME'] = text('DB Name', default: "{$appName}_db");
            $config['DB_USER'] = text('DB Username', default: "{$appName}_user");
            $config['DB_PASS'] = password('DB Password', required: true);
            $config['DB_ROOT_USER'] = text('MariaDB Root User', default: 'root');
            $config['DB_ROOT_PASS'] = password('MariaDB Root Password', required: true);
        }

        if (in_array('laravel_setup_php_fpm_pool', $steps) || in_array('laravel_configure_nginx', $steps)) {
            $config['PHP_VERSION'] = select('PHP Version', options: ['8.1', '8.2', '8.3', '8.4'], default: $server['php_version'] ?? '8.4');
        }

        if (in_array('nodejs_configure_nginx', $steps)) {
            $config['NODE_PORT'] = text('Node.js App Port', default: '3000', required: true);
        }

        if (in_array('setup_ssl', $steps)) {
            $config['EMAIL'] = text('SSL Admin Email', default: "admin@{$domain}", required: true);
        }

        return $config;
    }

    /**
     * Bundle required bash modules into a single execution stream.
     */
    protected function bundleScripts(array $modules): string
    {
        $basePath = base_path('scripts/sites');
        $script = "#!/bin/bash\n\n";

        foreach ($modules as $module) {
            $filePath = "{$basePath}/{$module}.sh";
            if (File::exists($filePath)) {
                $script .= File::get($filePath) . "\n";
            }
        }

        $script .= File::get("{$basePath}/dispatcher.sh");

        return $script;
    }
}
