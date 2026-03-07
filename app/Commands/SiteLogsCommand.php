<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

use function Laravel\Prompts\select;

class SiteLogsCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'site:logs {site? : The name of the site} {--follow : Follow the log in realtime}';

    protected $description = "View a site's application logs";

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
        $follow = $this->option('follow');

        $sites = $server['sites'] ?? [];

        if (empty($siteName) && !empty($sites)) {
            $siteOptions = collect($sites)->pluck('name', 'name')->toArray();
            $siteName = select(
                'Select a site to view logs for:',
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

        $logPath = $site['path'] . '/storage/logs/laravel.log';
        if (($site['type'] ?? 'laravel') !== 'laravel') {
            $logPath = "/var/log/nginx/{$siteName}_error.log";
        }

        $cmd = ($follow ? 'tail -f ' : 'tail -n 100 ') . escapeshellarg($logPath);
        $sshCmd = $this->sshService->buildCommand($server, $cmd);

        $this->components->info("Viewing logs for '{$siteName}'" . ($follow ? ' (following)' : '') . '...');

        passthru($sshCmd, $exitCode);

        return $exitCode;
    }
}
