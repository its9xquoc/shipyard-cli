<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

class SSHTestCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'ssh:test';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Test SSH connection to a VPS server';

    /**
     * Create a new command instance.
     */
    public function __construct(
        protected ServerRepository $repository,
        protected SSHService $sshService
    ) {
        parent::__construct();
    }

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $server = $this->chooseServer();

        $this->info("Testing connection to '{$server['name']}' ({$server['host']})...");

        if ($this->testConnection($server)) {
            $this->info('Connection successful: OK');
        } else {
            $this->error('Connection failed.');
        }

        return self::SUCCESS;
    }
}
