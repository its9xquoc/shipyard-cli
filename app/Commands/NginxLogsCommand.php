<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

class NginxLogsCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'nginx:logs {type? : error or access} {--follow : Follow the log in realtime}';

    protected $description = 'View Nginx log files';

    public function __construct(
        protected ServerRepository $repository,
        protected SSHService $sshService
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $server = $this->chooseServer();
        $type = $this->argument('type') ?? 'error';
        $follow = $this->option('follow');

        $logFile = "/var/log/nginx/{$type}.log";

        $cmd = ($follow ? 'tail -f ' : 'tail -n 100 ') . escapeshellarg($logFile);
        $sshCmd = $this->sshService->buildCommand($server, $cmd);

        $this->components->info("Viewing Nginx {$type} logs on '{$server['name']}'" . ($follow ? ' (following)' : '') . '...');

        passthru($sshCmd, $exitCode);

        return $exitCode;
    }
}
