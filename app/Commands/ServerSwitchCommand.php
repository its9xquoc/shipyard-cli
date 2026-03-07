<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Repositories\ServerRepository;
use Illuminate\Console\Command;

use function Laravel\Prompts\select;

class ServerSwitchCommand extends Command
{
    use InteractsWithServers;

    protected $signature = 'server:switch {name? : The name of the server to switch to}';

    protected $description = 'Switch the currently active server';

    public function __construct(
        protected ServerRepository $repository
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $name = $this->argument('name');
        $servers = $this->repository->getAllServers();

        if ($servers->isEmpty()) {
            $this->error('No servers found. Please add one first using server:add.');

            return self::FAILURE;
        }

        if ($name) {
            $server = $servers->first(fn ($s) => $s['name'] === $name);
            if (!$server) {
                // Try searching by ID
                $server = $servers->first(fn ($s) => (string) $s['id'] === $name);
            }

            if (!$server) {
                $this->error("Server '{$name}' not found.");

                return self::FAILURE;
            }
        } else {
            $options = $servers->pluck('name', 'id')->toArray();
            $id = select(
                'Select a server to switch to:',
                $options
            );
            $server = $servers->firstWhere('id', $id);
        }

        $this->repository->setActiveServerId($server['id']);

        $this->components->success("Active server switched to: '{$server['name']}'");

        return self::SUCCESS;
    }
}
