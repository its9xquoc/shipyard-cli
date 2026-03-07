<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

class PhpStatusCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'php:status {version? : The PHP version}';

    protected $description = 'Check the current status of PHP-FPM';

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

        $cmd = "systemctl status php{$version}-fpm --no-pager";
        $sshCmd = $this->sshService->buildCommand($server, $cmd);

        $this->components->info("Checking PHP {$version}-FPM status on '{$server['name']}'...");

        passthru($sshCmd, $exitCode);

        return $exitCode;
    }
}
