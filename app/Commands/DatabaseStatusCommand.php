<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

class DatabaseStatusCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'database:status';

    protected $description = 'Check the current status of the database';

    public function __construct(
        protected ServerRepository $repository,
        protected SSHService $sshService
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $server = $this->chooseServer();

        $cmd = 'systemctl status mariadb --no-pager || systemctl status mysql --no-pager';
        $sshCmd = $this->sshService->buildCommand($server, $cmd);

        $this->components->info("Checking Database status on '{$server['name']}'...");

        passthru($sshCmd, $exitCode);

        return $exitCode;
    }
}
