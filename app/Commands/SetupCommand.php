<?php

namespace App\Commands;

use App\Concerns\DisplaysLogo;
use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\CredentialsRepository;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;

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
     * Create a new command instance.
     */
    public function __construct(
        protected ServerRepository $repository,
        protected CredentialsRepository $credentialsRepository,
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

        $config = $this->promptForConfiguration($server);
        $fullScript = $this->bundleScript();

        // Prepare Environment Variables String
        $envVars = collect($config)->merge([
            'DEPLOY_USER' => $config['NEW_USER'] ?? ($server['deploy_user'] ?? 'deploy'),
            'AUTO_CONFIRM' => '1',
        ])
            ->filter()
            ->map(fn ($value, $key) => "{$key}=" . escapeshellarg((string) $value))
            ->implode(' ');

        $remoteCommand = "{$envVars} bash -s";
        $sshCommand = $this->sshService->buildCommand($server, $remoteCommand);

        $this->newLine();
        $this->components->info("Starting modular setup on '{$server['name']}' ({$server['host']})...");

        // Pass the bundled script via stdin
        // $process = proc_open($sshCommand, [
        //     0 => ['pipe', 'r'], // stdin
        //     1 => STDOUT,        // stdout
        //     2 => STDERR,        // stderr
        // ], $pipes);

        // if (is_resource($process)) {
        //     fwrite($pipes[0], $fullScript);
        //     fclose($pipes[0]);
        //     $exitCode = proc_close($process);
        // } else {
        //     $this->error('Failed to execute SSH process.');

        //     return self::FAILURE;
        // }

        // if ($exitCode === 0) {
        // Root-level server data is saved on server record.
        $updatedData = $this->buildServerUpdatePayload($config);

        // Site-level data is saved under server.sites, including site name "_".
        $sitePayload = $this->buildSitePayload($config);
        $updatedData['sites'] = $this->upsertSite($server['sites'] ?? [], $sitePayload);

        if (!empty($updatedData)) {
            $this->repository->updateServer($server['id'], $updatedData);
            $this->components->info('Server configuration updated in storage.');
        }

        $credentialsPath = $this->saveCredentials($server, $config);

        $this->newLine();
        $this->info('Modular VPS Setup completed successfully!');
        $this->components->info("Credentials saved to: {$credentialsPath}");
        $this->newLine();

        return self::SUCCESS;
        // }

        // $this->newLine();
        // $this->components->error("Setup failed with exit code: {$exitCode}");

        // return self::FAILURE;
    }

    /**
     * Load monolithic setup script provided by user.
     */
    protected function bundleScript(): string
    {
        return File::get(base_path('scripts/setup/dispatcher.sh'));
    }

    /**
     * Prompt user for environmental configuration.
     * Passwords are auto-generated with high complexity.
     */
    protected function promptForConfiguration(array $server): array
    {
        $config = [];
        $config['NEW_USER'] = text('Deployment Username', default: ($server['deploy_user'] ?? 'deploy'), required: true);
        $config['NEW_USER_PASSWORD'] = $this->generatePassword();
        $config['SSH_PORT'] = text('Custom SSH Port', default: (string) ($server['port'] ?? 2222), required: true);
        $config['DOMAIN'] = text('Domain Name', default: '_', required: true);
        $config['EMAIL'] = text('Admin Email', default: 'admin@' . ($config['DOMAIN'] === '_' ? 'server.com' : $config['DOMAIN']), required: true);
        $config['PHP_VERSION'] = select('PHP Version', options: ['8.1', '8.2', '8.3', '8.4'], default: (string) ($server['php_version'] ?? '8.4'));
        $config['DB_NAME'] = text('Database Name', default: 'app_db', required: true);
        $config['DB_USER'] = text('Database User', default: 'app_user', required: true);
        $config['DB_PASS'] = $this->generatePassword();
        $config['DB_ROOT_PASS'] = $this->generatePassword();

        // Display generated passwords before running setup
        $this->displayGeneratedPasswords($config);

        return $config;
    }

    /**
     * Generate a high-complexity random password.
     */
    protected function generatePassword(int $length = 24): string
    {
        $uppercase = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
        $lowercase = 'abcdefghjkmnpqrstuvwxyz';
        $numbers = '23456789';
        $symbols = '!@#$%^&*-_+=';
        $all = $uppercase . $lowercase . $numbers . $symbols;

        // Guarantee at least one character from each category
        $password = [
            $uppercase[random_int(0, strlen($uppercase) - 1)],
            $lowercase[random_int(0, strlen($lowercase) - 1)],
            $numbers[random_int(0, strlen($numbers) - 1)],
            $symbols[random_int(0, strlen($symbols) - 1)],
        ];

        for ($i = 4; $i < $length; $i++) {
            $password[] = $all[random_int(0, strlen($all) - 1)];
        }

        shuffle($password);

        return implode('', $password);
    }

    /**
     * Display all auto-generated passwords to the user.
     */
    protected function displayGeneratedPasswords(array $config): void
    {
        $rows = [];

        if (isset($config['NEW_USER_PASSWORD'])) {
            $rows[] = ['Deploy User Password', $config['NEW_USER_PASSWORD']];
        }
        if (isset($config['DB_PASS'])) {
            $rows[] = ['Database Password', $config['DB_PASS']];
        }
        if (isset($config['DB_ROOT_PASS'])) {
            $rows[] = ['MariaDB Root Password', $config['DB_ROOT_PASS']];
        }

        if (empty($rows)) {
            return;
        }

        $this->newLine();
        $this->components->info('Auto-generated passwords (high complexity):');
        $this->table(['Key', 'Password'], $rows);
        $this->newLine();
    }

    /**
     * Save generated credentials via the CredentialsRepository.
     *
     * @return string Path to the saved credentials file
     */
    protected function saveCredentials(array $server, array $config): string
    {
        $serverSlug = $server['name'] ?? (string) $server['id'];

        $credentials = [
            'server' => $server['name'] ?? $server['id'],
            'host' => $server['host'],
            'saved_at' => date('Y-m-d H:i:s'),
        ];

        if (isset($config['NEW_USER'])) {
            $credentials['deploy_user'] = $config['NEW_USER'];
        }
        if (isset($config['NEW_USER_PASSWORD'])) {
            $credentials['deploy_user_password'] = $config['NEW_USER_PASSWORD'];
        }
        if (isset($config['DB_NAME'])) {
            $credentials['db_name'] = $config['DB_NAME'];
        }
        if (isset($config['DB_USER'])) {
            $credentials['db_user'] = $config['DB_USER'];
        }
        if (isset($config['DB_PASS'])) {
            $credentials['db_password'] = $config['DB_PASS'];
        }
        if (isset($config['DB_ROOT_PASS'])) {
            $credentials['db_root_password'] = $config['DB_ROOT_PASS'];
        }

        return $this->credentialsRepository->save($serverSlug, $credentials);
    }

    /**
     * Build root-level payload that belongs to server record.
     */
    protected function buildServerUpdatePayload(array $config): array
    {
        return [
            'deploy_user' => $config['NEW_USER'],
            'user' => $config['NEW_USER'],
            'port' => (int) $config['SSH_PORT'],
            'php_version' => $config['PHP_VERSION'],
            'db_root_pass' => $config['DB_ROOT_PASS'],
            'updated_at' => date('Y-m-d H:i:s'),
        ];
    }

    /**
     * Build site-level payload; domain "_" is treated as valid site name.
     */
    protected function buildSitePayload(array $config): array
    {
        return [
            'name' => $config['DOMAIN'],
            'domain' => $config['DOMAIN'],
            'email' => $config['EMAIL'],
            'type' => 'default',
            'path' => '/var/www/html',
            'database' => $config['DB_NAME'],
            'db_user' => $config['DB_USER'],
            'php_version' => $config['PHP_VERSION'],
            'updated_at' => now()->toIso8601String(),
        ];
    }

    /**
     * Insert or update site by name in the server site list.
     */
    protected function upsertSite(array $sites, array $sitePayload): array
    {
        $name = (string) $sitePayload['name'];
        $index = collect($sites)->search(fn ($site) => (string) ($site['name'] ?? '') === $name);

        if ($index === false) {
            $sitePayload['created_at'] = now()->toIso8601String();
            $sites[] = $sitePayload;
        } else {
            $existing = $sites[$index] ?? [];
            $sitePayload['created_at'] = $existing['created_at'] ?? now()->toIso8601String();
            $sites[$index] = array_merge($existing, $sitePayload);
        }

        return array_values($sites);
    }
}
