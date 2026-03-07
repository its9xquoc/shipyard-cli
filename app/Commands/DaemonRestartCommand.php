<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

use function Laravel\Prompts\text;

class DaemonRestartCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'daemon:restart {name? : The daemon name}';

    protected $description = 'Restart a PM2 daemon';

    public function __construct(
        protected ServerRepository $repository,
        protected SSHService $sshService
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $server = $this->chooseServer();
        $name = $this->argument('name');

        if (empty($name)) {
            $name = text('Enter PM2 process name or all:', default: 'all');
        }

        $cmd = 'pm2 restart ' . escapeshellarg($name);
        $sshCmd = $this->sshService->buildCommand($server, $cmd);

        $this->components->info("Restarting PM2 daemon '{$name}' on '{$server['name']}'...");

        passthru($sshCmd, $exitCode);

        return $exitCode;
    }
}
