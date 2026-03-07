<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

class SSHCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'ssh {server? : The name of the server}';

    protected $description = 'Open an interactive SSH shell on a VPS server';

    public function __construct(
        protected ServerRepository $repository,
        protected SSHService $sshService
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $serverName = $this->argument('server');

        if ($serverName) {
            $servers = $this->repository->getAllServers();
            $server = $servers->first(fn ($s) => $s['name'] === $serverName);

            if (!$server) {
                $this->error("Server '{$serverName}' not found.");

                return self::FAILURE;
            }
        } else {
            $server = $this->chooseServer();
        }

        $sshCmd = $this->sshService->buildCommand($server, '');

        // For interactive shell, we remove the trailing empty string command
        $sshCmd = preg_replace('/ ""$/', '', $sshCmd);

        $this->components->info("Connecting to '{$server['name']}' ({$server['host']})...");

        // Use passthru for interactive shell
        passthru($sshCmd, $exitCode);

        return $exitCode;
    }
}
