<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

class NginxRestartCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'nginx:restart';

    protected $description = 'Restart Nginx';

    public function __construct(
        protected ServerRepository $repository,
        protected SSHService $sshService
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $server = $this->chooseServer();

        $cmd = 'sudo systemctl restart nginx';
        $sshCmd = $this->sshService->buildCommand($server, $cmd);

        $this->components->info("Restarting Nginx on '{$server['name']}'...");

        passthru($sshCmd, $exitCode);

        if ($exitCode === 0) {
            $this->components->success('Nginx restarted successfully.');
        }

        return $exitCode;
    }
}
