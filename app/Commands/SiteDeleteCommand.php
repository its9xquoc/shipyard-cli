<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

use function Laravel\Prompts\confirm;
use function Laravel\Prompts\select;

class SiteDeleteCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'site:delete';

    protected $description = 'Delete a Website from a VPS server (All Types)';

    public function __construct(
        protected ServerRepository $repository,
        protected SSHService $sshService
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $server = $this->chooseServer();

        $sites = $server['sites'] ?? [];
        if (empty($sites)) {
            $this->error('No sites configured for this server.');

            return self::FAILURE;
        }

        $appName = select(
            'Select the site to delete:',
            collect($sites)->pluck('name', 'name')->toArray()
        );

        $site = (array) collect($sites)->firstWhere('name', $appName);
        if (!$site) {
            $this->error('Site data not found.');

            return self::FAILURE;
        }

        if (!confirm("Are you sure you want to delete site '{$appName}'? This will remove Nginx, PHP pool, or PM2 process. (Local data and database will be kept)")) {
            $this->info('Aborted.');

            return self::SUCCESS;
        }

        $phpVersion = $site['php_version'] ?? $server['php_version'] ?? '8.4';

        // Execute remote universal cleanup
        $vars = [
            "APP_NAME=\"{$appName}\"",
            "PHP_VERSION=\"{$phpVersion}\"",
            "APP_PATH=\"{$site['path']}\"",
        ];

        $envString = implode(' ', $vars);
        $remoteCmd = "{$envString} bash -s";
        $sshCmd = $this->sshService->buildCommand($server, $remoteCmd);

        $scriptPath = base_path('scripts/sites/delete.sh');
        $fullCommand = "{$sshCmd} < \"{$scriptPath}\"";

        passthru($fullCommand, $exitCode);

        // Remove from local config anyway if successful
        if ($exitCode === 0) {
            $remainingSites = collect($sites)->reject(fn ($s) => $s['name'] === $appName)->values()->toArray();
            $this->repository->updateServer($server['id'], ['sites' => $remainingSites]);

            $this->info("Site '{$appName}' removed from server config and system resources.");

            return self::SUCCESS;
        }

        $this->components->error("Failed to cleanup site on server. Exit code: {$exitCode}");

        return self::FAILURE;
    }
}
