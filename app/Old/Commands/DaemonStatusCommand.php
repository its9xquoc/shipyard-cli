<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

class DaemonStatusCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'daemon:status';

    protected $description = 'Check the status of running PM2 daemons';

    public function __construct(
        protected ServerRepository $repository,
        protected SSHService $sshService
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $server = $this->chooseServer();

        $cmd = 'pm2 list';
        $sshCmd = $this->sshService->buildCommand($server, $cmd);

        $this->components->info("Checking PM2 daemons on '{$server['name']}'...");

        passthru($sshCmd, $exitCode);

        return $exitCode;
    }
}
