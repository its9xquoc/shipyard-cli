<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Services\ServerRepository;
use Illuminate\Console\Command;

use function Laravel\Prompts\text;

class ServerEditCommand extends Command
{
    use InteractsWithServers;

    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'server:edit';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Edit an existing VPS server';

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

        $name = text(
            label: 'Server name',
            default: $server['name'],
            required: true
        );

        $host = text(
            label: 'Host IP/Domain',
            default: $server['host'],
            required: true
        );

        $port = text(
            label: 'SSH Port',
            default: (string) $server['port'],
            required: true,
            validate: fn (string $value) => is_numeric($value) ? null : 'Port must be a number'
        );

        $user = text(
            label: 'SSH User',
            default: $server['user'],
            required: true
        );

        $privateKey = text(
            label: 'Private Key Path',
            default: $server['private_key'],
            required: true
        );

        $this->repository->updateServer($server['id'], [
            'name' => $name,
            'host' => $host,
            'port' => (int) $port,
            'user' => $user,
            'private_key' => $privateKey,
        ]);

        $this->info('Server updated successfully.');

        return self::SUCCESS;
    }
}
