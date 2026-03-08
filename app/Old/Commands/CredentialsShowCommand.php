<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Repositories\CredentialsRepository;
use App\Repositories\ServerRepository;
use Illuminate\Console\Command;

class CredentialsShowCommand extends Command
{
    use InteractsWithServers;

    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'credentials:show {server? : Server name or ID}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Show saved setup credentials/passwords for a server';

    /**
     * Create a new command instance.
     */
    public function __construct(
        protected ServerRepository $repository,
        protected CredentialsRepository $credentialsRepository
    ) {
        parent::__construct();
    }

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $serverInput = $this->argument('server');
        $server = $this->resolveServer($serverInput);

        if (!$server) {
            $this->error('Server not found.');

            return self::FAILURE;
        }

        $slug = (string) ($server['name'] ?? $server['id']);

        if (!$this->credentialsRepository->exists($slug)) {
            $this->warn("No saved credentials found for server '{$server['name']}'.");
            $this->line('Run setup first to generate and save passwords.');

            return self::SUCCESS;
        }

        $credentials = $this->credentialsRepository->get($slug);

        $this->newLine();
        $this->components->info("Credentials for '{$server['name']}' ({$server['host']}):");

        $rows = collect($credentials)
            ->map(fn ($value, $key) => [$key, is_scalar($value) ? (string) $value : json_encode($value)])
            ->toArray();

        $this->table(['Key', 'Value'], $rows);

        return self::SUCCESS;
    }

    /**
     * Resolve server by argument, active server, or interactive selection.
     */
    protected function resolveServer(mixed $serverInput): ?array
    {
        if ($serverInput !== null && $serverInput !== '') {
            $servers = $this->loadServers();

            if (is_numeric($serverInput)) {
                $match = $servers->firstWhere('id', (int) $serverInput);

                return $match ? (array) $match : null;
            }

            $match = $servers->firstWhere('name', (string) $serverInput);

            return $match ? (array) $match : null;
        }

        return $this->chooseServer();
    }
}
