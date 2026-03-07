<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Repositories\ServerRepository;
use Illuminate\Console\Command;

class ServerCurrentCommand extends Command
{
    use InteractsWithServers;

    protected $signature = 'server:current';

    protected $description = 'View the currently active server';

    public function __construct(
        protected ServerRepository $repository
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $currentId = $this->repository->getActiveServerId();

        if (!$currentId) {
            $this->warn('No server is currently active. Use server:switch to set one.');

            return self::SUCCESS;
        }

        $server = $this->findServerById($currentId);

        if (!$server) {
            $this->error("Active server with ID {$currentId} no longer exists.");

            return self::FAILURE;
        }

        $this->components->info("Current Active Server: '{$server['name']}' ({$server['host']}) [ID: {$currentId}]");

        return self::SUCCESS;
    }
}
