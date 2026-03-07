<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

use function Laravel\Prompts\select;
use function Laravel\Prompts\text;

class CommandCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'command {site? : The name of the site} {--command= : The command to run}';

    protected $description = 'Run an arbitrary shell command on a VPS server/site';

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
        $cmd = $this->option('command');

        $sites = $server['sites'] ?? [];

        if (empty($siteName) && !empty($sites)) {
            $siteOptions = collect($sites)->pluck('name', 'name')->toArray();
            $siteOptions = array_merge(['' => 'None (Run in home directory)'], $siteOptions);
            $siteName = (string) select(
                'Select a site to run the command in (Optional):',
                $siteOptions
            );
        }

        if (empty($cmd)) {
            $cmd = text('Enter the command to run:', placeholder: 'ls -la', required: true);
        }

        $remoteDir = '';
        if ($siteName) {
            $site = (array) collect($sites)->firstWhere('name', $siteName);
            if (!empty($site)) {
                $remoteDir = 'cd ' . escapeshellarg($site['path']) . ' && ';
            }
        }

        $fullRemoteCmd = $remoteDir . $cmd;
        $sshCmd = $this->sshService->buildCommand($server, $fullRemoteCmd);

        $this->components->info("Running '{$cmd}' on '{$server['name']}'" . ($siteName ? " in '{$siteName}'" : '') . '...');

        passthru($sshCmd, $exitCode);

        return $exitCode;
    }
}
