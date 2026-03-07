<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

class NginxStatusCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'nginx:status';

    protected $description = 'Check the current status of Nginx';

    public function __construct(
        protected ServerRepository $repository,
        protected SSHService $sshService
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $server = $this->chooseServer();

        $cmd = 'systemctl status nginx --no-pager';
        $sshCmd = $this->sshService->buildCommand($server, $cmd);

        $this->components->info("Checking Nginx status on '{$server['name']}'...");

        passthru($sshCmd, $exitCode);

        return $exitCode;
    }
}
