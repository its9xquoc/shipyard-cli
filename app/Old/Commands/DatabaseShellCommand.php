<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

class DatabaseShellCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'database:shell {db? : The database name} {--user= : The database user}';

    protected $description = 'Access a command line shell for the database';

    public function __construct(
        protected ServerRepository $repository,
        protected SSHService $sshService
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $server = $this->chooseServer();
        $db = $this->argument('db');
        $user = $this->option('user') ?? 'root';

        // Use root password if stored and user is root
        $passPart = '';
        if ($user === 'root' && !empty($server['db_root_pass'])) {
            $passPart = ' -p' . escapeshellarg($server['db_root_pass']);
        }

        $cmd = 'mysql -u ' . escapeshellarg($user) . $passPart . ($db ? ' ' . escapeshellarg($db) : '');
        $sshCmd = $this->sshService->buildCommand($server, $cmd);

        // Remove trailing empty string
        $sshCmd = preg_replace('/ ""$/', '', $sshCmd);

        $this->components->info("Connecting to Database shell on '{$server['name']}'...");

        passthru($sshCmd, $exitCode);

        return $exitCode;
    }
}
