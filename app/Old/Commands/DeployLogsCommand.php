<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

use function Laravel\Prompts\select;

class DeployLogsCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'deploy:logs {site? : The name of the site} {deployment? : Optional deployment ID or filename}';

    protected $description = 'Review the output / logs for the latest deployment';

    public function __construct(
        protected ServerRepository $repository,
        protected SSHService $sshService
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $server = $this->chooseServer();
        $siteName = $this->argument('site');
        $deployment = $this->argument('deployment');

        $sites = $server['sites'] ?? [];

        if (empty($siteName) && !empty($sites)) {
            $siteOptions = collect($sites)->pluck('name', 'name')->toArray();
            $siteName = select(
                'Select a site to view deployment logs:',
                $siteOptions
            );
        }

        if (empty($siteName)) {
            $this->error('No site selected or found.');

            return self::FAILURE;
        }

        $site = (array) collect($sites)->firstWhere('name', $siteName);
        if (empty($site)) {
            $this->error("Site '{$siteName}' not found on server.");

            return self::FAILURE;
        }

        // We assume deploy.sh logs to deployment.log or similar
        $logPath = $site['path'] . '/deployment.log';

        $cmd = 'tail -n 100 ' . escapeshellarg($logPath);
        $sshCmd = $this->sshService->buildCommand($server, $cmd);

        $this->components->info("Viewing deployment logs for '{$siteName}'...");

        passthru($sshCmd, $exitCode);

        return $exitCode;
    }
}
