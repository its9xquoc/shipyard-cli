<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Repositories\ServerRepository;
use Illuminate\Console\Command;

use function Laravel\Prompts\confirm;

class ServerDeleteCommand extends Command
{
    use InteractsWithServers;

    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'server:delete';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Delete a VPS server';

    /**
     * Create a new command instance.
     */
    public function __construct(
        protected ServerRepository $repository
    ) {
        parent::__construct();
    }

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $server = $this->chooseServer();

        if (confirm("Are you sure you want to delete server '{$server['name']}'?")) {
            $this->repository->deleteServer($server['id']);
            $this->info('Server deleted successfully.');
        }

        return self::SUCCESS;
    }
}
