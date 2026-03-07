<?php

namespace App\Commands;

use App\Repositories\ServerRepository;
use Illuminate\Console\Command;

use function Laravel\Prompts\confirm;

class StorageClearCommand extends Command
{
    protected $signature = 'storage:clear';

    protected $description = 'Clear all local Shipyard storage data (servers, tokens, etc.)';

    public function __construct(
        protected ServerRepository $repository
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $path = config('shipyard.storage_path');

        if (!file_exists($path)) {
            $this->info('No storage file found. Nothing to clear.');

            return self::SUCCESS;
        }

        $this->warn("This will delete all your configured servers and API tokens from: {$path}");

        if (!confirm('Are you sure you want to proceed?', default: false)) {
            $this->info('Operation aborted.');

            return self::SUCCESS;
        }

        if (unlink($path)) {
            $this->info('Shipyard storage cleared successfully.');

            return self::SUCCESS;
        }

        $this->error('Failed to delete storage file. Check your permissions.');

        return self::FAILURE;
    }
}
