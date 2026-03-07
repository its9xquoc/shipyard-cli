<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

use function Laravel\Prompts\text;

class DaemonLogsCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'daemon:logs {name? : The daemon name} {--follow : Follow the log in realtime}';

    protected $description = 'View PM2 daemon logs';

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
        $follow = $this->option('follow');

        if (empty($name)) {
            $name = text('Enter PM2 process name:', required: true);
        }

        $cmd = 'pm2 logs ' . escapeshellarg($name) . ($follow ? '' : ' --lines 100 --no-pager');
        $sshCmd = $this->sshService->buildCommand($server, $cmd);

        $this->components->info("Viewing PM2 logs for '{$name}' on '{$server['name']}'" . ($follow ? ' (following)' : '') . '...');

        passthru($sshCmd, $exitCode);

        return $exitCode;
    }
}
