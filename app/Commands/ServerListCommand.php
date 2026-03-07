<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Repositories\ServerRepository;
use Illuminate\Console\Command;

class ServerListCommand extends Command
{
    use InteractsWithServers;

    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'server:list';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'List all configured VPS servers';

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
        $servers = $this->loadServers();

        if ($servers->isEmpty()) {
            $this->info('No servers configured.');

            return self::SUCCESS;
        }

        $this->table(
            ['ID', 'Name', 'Host', 'Port', 'User'],
            $servers->map(fn ($server) => [
                $server['id'],
                $server['name'],
                $server['host'],
                $server['port'],
                $server['user'],
            ])->toArray()
        );

        return self::SUCCESS;
    }
}
