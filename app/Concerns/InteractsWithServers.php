<?php

namespace App\Concerns;

use Illuminate\Support\Collection;

use function Laravel\Prompts\select;

trait InteractsWithServers
{
    /**
     * Load all servers from the repository.
     */
    protected function loadServers(): Collection
    {
        return $this->repository->getAllServers();
    }

    /**
     * Prompt user to choose a server.
     */
    protected function chooseServer(): array
    {
        $servers = $this->loadServers();

        if ($servers->isEmpty()) {
            $this->error('No servers found.');
            exit(1);
        }

        $id = select(
            label: 'Choose a server',
            options: $servers->pluck('name', 'id')->toArray()
        );

        return $servers->firstWhere('id', (int) $id);
    }

    /**
     * Find a server by its ID.
     */
    protected function findServerById(int $id): ?array
    {
        return $this->loadServers()->firstWhere('id', $id);
    }
}
