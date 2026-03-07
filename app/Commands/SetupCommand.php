<?php

namespace App\Commands;

use App\Concerns\DisplaysLogo;
use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;

use function Laravel\Prompts\multiselect;
use function Laravel\Prompts\password;
use function Laravel\Prompts\select;
use function Laravel\Prompts\text;

class SetupCommand extends Command
{
    use DisplaysLogo, InteractsWithServers, InteractsWithSSH;

    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'setup';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Modular VPS Setup Orchestrator';

    /**
     * Logical mapping of steps to their script modules.
     */
    protected array $stepDefinitions = [
        'update_system' => ['module' => 'system', 'label' => 'Update System Packages'],
        'setup_timezone' => ['module' => 'system', 'label' => 'Configure Timezone (UTC)'],
        'create_user' => ['module' => 'system', 'label' => 'Create Non-Root User'],
        'setup_ssh_keys' => ['module' => 'system', 'label' => 'Setup SSH Keys for New User'],
        'configure_ssh' => ['module' => 'security', 'label' => 'Configure SSH Security'],
        'create_ssh_hardening_script' => ['module' => 'security', 'label' => 'Create SSH Hardening Script'],
        'setup_firewall' => ['module' => 'security', 'label' => 'Configure UFW Firewall'],
        'setup_fail2ban' => ['module' => 'security', 'label' => 'Configure Fail2Ban'],
        'install_nginx' => ['module' => 'web', 'label' => 'Install Nginx Web Server'],
        'install_php' => ['module' => 'web', 'label' => 'Install PHP with Extensions'],
        'install_composer' => ['module' => 'web', 'label' => 'Install Composer'],
        'install_nodejs' => ['module' => 'web', 'label' => 'Install Node.js & PM2'],
        'install_mariadb' => ['module' => 'database', 'label' => 'Install & Secure MariaDB'],
        'install_redis' => ['module' => 'database', 'label' => 'Install & Secure Redis'],
        'create_default_site' => ['module' => 'final', 'label' => 'Create Default Website (Nginx)'],
        'optimize_system' => ['module' => 'final', 'label' => 'Apply System Optimizations'],
        'create_deployment_scripts' => ['module' => 'final', 'label' => 'Create Deployment & Site Scripts'],
        'setup_ssl' => ['module' => 'final', 'label' => 'Setup SSL (Certbot)'],
    ];

    /**
     * Create a new command instance.
     */
    public function __construct(
        protected ServerRepository $repository,
        protected SSHService $sshService
    ) {
        parent::__construct();
    }

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $this->displayLogo();
        $server = $this->chooseServer();

        $options = collect($this->stepDefinitions)->mapWithKeys(fn ($item, $key) => [$key => $item['label']])->toArray();

        $selectedStepKeys = multiselect(
            label: 'Select setup steps to execute:',
            options: $options,
            default: array_keys($options),
            required: true
        );

        $config = $this->promptForConfiguration($selectedStepKeys, $server);

        // Determine which modules are needed
        $neededModules = collect($selectedStepKeys)
            ->map(fn ($key) => $this->stepDefinitions[$key]['module'])
            ->unique()
            ->toArray();

        // Build the full script content
        $fullScript = $this->bundleScripts($neededModules);

        // Prepare Environment Variables String
        $envVars = collect($config)->merge([
            'DEPLOY_USER' => $config['NEW_USER'] ?? ($server['deploy_user'] ?? 'deploy'),
        ])
            ->filter()
            ->map(fn ($value, $key) => "{$key}=" . escapeshellarg((string) $value))
            ->implode(' ');

        // Prepare Step Arguments
        $args = array_map(function ($step) use ($config) {
            return ($step === 'install_php') ? "install_php:{$config['PHP_VERSION']}" : $step;
        }, $selectedStepKeys);

        $remoteCommand = "{$envVars} bash -s -- " . implode(' ', $args);
        $sshCommand = $this->sshService->buildCommand($server, $remoteCommand);

        $this->newLine();
        $this->components->info("Starting modular setup on '{$server['name']}' ({$server['host']})...");

        // Pass the bundled script via stdin
        $process = proc_open($sshCommand, [
            0 => ['pipe', 'r'], // stdin
            1 => STDOUT,        // stdout
            2 => STDERR,        // stderr
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
            // Update server configuration in storage if it was changed
            $updatedData = [];
            if (isset($config['NEW_USER'])) {
                $updatedData['user'] = $config['NEW_USER'];
            }
            if (isset($config['SSH_PORT'])) {
                $updatedData['port'] = (int) $config['SSH_PORT'];
            }

            if (!empty($config['DB_ROOT_PASS'])) {
                $updatedData['db_root_pass'] = $config['DB_ROOT_PASS'];
            }
            if (!empty($config['PHP_VERSION'])) {
                $updatedData['php_version'] = $config['PHP_VERSION'];
            }

            if (!empty($updatedData)) {
                $this->repository->updateServer($server['id'], $updatedData);
                $this->components->info('Server configuration updated in storage.');
            }

            $this->newLine();
            $this->components->success('Modular VPS Setup completed successfully!');

            return self::SUCCESS;
        }

        $this->newLine();
        $this->components->error("Setup failed with exit code: {$exitCode}");

        return self::FAILURE;
    }

    /**
     * Bundle required modules into a single script.
     */
    protected function bundleScripts(array $modules): string
    {
        $basePath = base_path('scripts/setup');
        $script = "#!/bin/bash\n\n";

        // Always include common.sh
        $script .= File::get("{$basePath}/common.sh") . "\n";

        // Include needed modules
        foreach ($modules as $module) {
            $filePath = "{$basePath}/{$module}.sh";
            if (File::exists($filePath)) {
                $script .= File::get($filePath) . "\n";
            }
        }

        // Always include dispatcher.sh at the end
        $script .= File::get("{$basePath}/dispatcher.sh");

        return $script;
    }

    /**
     * Prompt user for environmental configuration.
     */
    protected function promptForConfiguration(array $selectedStepKeys, array $server): array
    {
        $config = [];

        if (in_array('create_user', $selectedStepKeys)) {
            $config['NEW_USER'] = text('Deployment Username', default: ($server['deploy_user'] ?? 'deploy'), required: true);
            $config['NEW_USER_PASSWORD'] = password('Deployment User Password', placeholder: 'Min 8 characters', required: true);
        }

        if (array_intersect(['configure_ssh', 'setup_fail2ban'], $selectedStepKeys)) {
            $config['SSH_PORT'] = text('Custom SSH Port', default: '2222', required: true);
        }

        if (array_intersect(['install_nginx', 'setup_ssl', 'create_default_site'], $selectedStepKeys)) {
            $config['DOMAIN'] = text('Domain Name', default: '_', required: true);
            $config['EMAIL'] = text('Admin Email', default: 'admin@' . ($config['DOMAIN'] === '_' ? 'server.com' : $config['DOMAIN']), required: true);
        }

        if (in_array('install_php', $selectedStepKeys)) {
            $config['PHP_VERSION'] = select('PHP Version', options: ['8.1', '8.2', '8.3', '8.4'], default: '8.4');
        }

        if (in_array('install_mariadb', $selectedStepKeys)) {
            $config['DB_NAME'] = text('Database Name', default: 'app_db', required: true);
            $config['DB_USER'] = text('Database User', default: 'app_user', required: true);
            $config['DB_PASS'] = password('Database Password', required: true);
            $config['DB_ROOT_PASS'] = password('MariaDB Root Password', required: true);
        }

        if (in_array('install_nodejs', $selectedStepKeys)) {
            $config['NODE_VERSION'] = select('Node.js Version', options: ['18', '20', '22'], default: '20');
        }

        return $config;
    }
}
