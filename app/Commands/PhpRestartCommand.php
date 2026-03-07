<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

class PhpRestartCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'php:restart {version? : The PHP version}';

    protected $description = 'Restart PHP-FPM';

    public function __construct(
        protected ServerRepository $repository,
        protected SSHService $sshService
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $server = $this->chooseServer();
        $version = $this->argument('version') ?? '8.4';

        $cmd = "sudo systemctl restart php{$version}-fpm";
        $sshCmd = $this->sshService->buildCommand($server, $cmd);

        $this->components->info("Restarting PHP {$version}-FPM on '{$server['name']}'...");

        passthru($sshCmd, $exitCode);

        if ($exitCode === 0) {
            $this->components->success("PHP {$version}-FPM restarted successfully.");
        }

        return $exitCode;
    }
}
