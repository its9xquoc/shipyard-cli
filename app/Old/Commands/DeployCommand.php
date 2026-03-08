<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

use function Laravel\Prompts\select;

class DeployCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'deploy {site? : The name of the site}';

    protected $description = 'Initiate a deployment for a given site';

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

        $sites = $server['sites'] ?? [];

        if (empty($siteName) && !empty($sites)) {
            $siteOptions = collect($sites)->pluck('name', 'name')->toArray();
            $siteName = select(
                'Select a site to deploy:',
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

        $deployScript = $site['path'] . '/deploy.sh';

        // Build command to run deploy script
        $cmd = 'bash ' . escapeshellarg($deployScript);
        $sshCmd = $this->sshService->buildCommand($server, $cmd);

        $this->components->info("Initiating deployment for '{$siteName}' on '{$server['name']}'...");

        passthru($sshCmd, $exitCode);

        if ($exitCode === 0) {
            $this->info("Deployment completed successfully for '{$siteName}'.");
        } else {
            $this->components->error("Deployment failed with exit code {$exitCode}.");
        }

        return $exitCode;
    }
}
