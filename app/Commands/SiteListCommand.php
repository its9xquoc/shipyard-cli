<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Services\ServerRepository;
use Illuminate\Console\Command;

class SiteListCommand extends Command
{
    use InteractsWithServers;

    protected $signature = 'site:list';

    protected $description = 'List all websites on a specific VPS server';

    public function __construct(
        protected ServerRepository $repository
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $server = $this->chooseServer();

        $sites = $server['sites'] ?? [];

        if (empty($sites)) {
            $this->info("No sites found on server '{$server['name']}'.");

            return self::SUCCESS;
        }

        $this->info("Websites on server: {$server['name']} ({$server['host']})");

        $this->table(
            ['App Name', 'Type', 'Domain', 'Path', 'DB', 'Created At'],
            collect($sites)->map(fn ($site) => [
                $site['name'],
                strtoupper($site['type'] ?? 'Laravel'),
                $site['domain'],
                $site['path'],
                $site['database'] ?? 'N/A',
                $site['created_at'] ?? 'N/A',
            ])->toArray()
        );

        return self::SUCCESS;
    }
}
