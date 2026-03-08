<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

class DatabaseRestartCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'database:restart';

    protected $description = 'Restart the database';

    public function __construct(
        protected ServerRepository $repository,
        protected SSHService $sshService
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $server = $this->chooseServer();

        $cmd = 'sudo systemctl restart mariadb || sudo systemctl restart mysql';
        $sshCmd = $this->sshService->buildCommand($server, $cmd);

        $this->components->info("Restarting Database on '{$server['name']}'...");

        passthru($sshCmd, $exitCode);

        if ($exitCode === 0) {
            $this->info('Database restarted successfully.');
        }

        return $exitCode;
    }
}
