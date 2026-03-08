<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

use function Laravel\Prompts\select;

class TinkerCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'tinker {site? : The name of the site}';

    protected $description = 'Enter a Tinker environment on a remote server/site';

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
            // Only list Laravel sites for tinker
            $siteOptions = collect($sites)
                ->filter(fn ($s) => ($s['type'] ?? 'laravel') === 'laravel')
                ->pluck('name', 'name')
                ->toArray();

            if (empty($siteOptions)) {
                $this->error('No Laravel sites found on this server.');

                return self::FAILURE;
            }

            $siteName = select(
                'Select a Laravel site to Tinker in:',
                $siteOptions
            );
        }

        if (empty($siteName)) {
            $this->error('No site selected.');

            return self::FAILURE;
        }

        $site = (array) collect($sites)->firstWhere('name', $siteName);
        if (empty($site)) {
            $this->error("Site '{$siteName}' not found.");

            return self::FAILURE;
        }

        $remoteDir = $site['path'];
        $cmd = 'cd ' . escapeshellarg($remoteDir) . ' && php artisan tinker';
        $sshCmd = $this->sshService->buildCommand($server, $cmd);

        $sshCmd = preg_replace('/ ""$/', '', $sshCmd);

        $this->components->info("Starting Tinker session in '{$siteName}'...");

        passthru($sshCmd, $exitCode);

        return $exitCode;
    }
}
