<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

class PhpLogsCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'php:logs {version? : The PHP version}';

    protected $description = 'View PHP error logs';

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

        $logFile = "/var/log/php{$version}-fpm.log";

        $cmd = 'tail -n 100 ' . escapeshellarg($logFile);
        $sshCmd = $this->sshService->buildCommand($server, $cmd);

        $this->components->info("Viewing PHP {$version}-FPM logs on '{$server['name']}'...");

        passthru($sshCmd, $exitCode);

        return $exitCode;
    }
}
