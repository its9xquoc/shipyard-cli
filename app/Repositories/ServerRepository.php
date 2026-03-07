<?php

namespace App\Repositories;

use App\Services\YamlStorage;
use Illuminate\Support\Collection;

class ServerRepository
{
    protected string $path;

    public function __construct(
        protected YamlStorage $storage
    ) {
        $this->path = config('shipyard.storage_path');
    }

    /**
     * Get all servers.
     */
    public function getAllServers(): Collection
    {
        $data = $this->storage->read($this->path);

        return collect($data['servers'] ?? []);
    }

    /**
     * Add a new server.
     */
    public function addServer(array $server): void
    {
        $servers = $this->getAllServers();
        $server['id'] = ($servers->max('id') ?? 0) + 1;
        $servers->push($server);
        $this->save($servers);
    }

    /**
     * Update an existing server.
     */
    public function updateServer(int $id, array $updatedData): void
    {
        $servers = $this->getAllServers()->map(function ($server) use ($id, $updatedData) {
            if ($server['id'] === $id) {
                return array_merge($server, $updatedData);
            }

            return $server;
        });

        $this->save($servers);
    }

    /**
     * Delete a server by ID.
     */
    public function deleteServer(int $id): void
    {
        $servers = $this->getAllServers()->reject(fn ($server) => $server['id'] === $id);

        $this->save($servers->values());
    }

    /**
     * Get the ID of the currently active server.
     */
    public function getActiveServerId(): ?int
    {
        $data = $this->storage->read($this->path);

        return $data['active_server_id'] ?? null;
    }

    /**
     * Set the ID of the currently active server.
     */
    public function setActiveServerId(int $id): void
    {
        $servers = $this->getAllServers();
        $this->save($servers, $id);
    }

    /**
     * Get the API token.
     */
    public function getApiToken(): ?string
    {
        $data = $this->storage->read($this->path);

        return $data['api_token'] ?? null;
    }

    /**
     * Set the API token.
     */
    public function setApiToken(string $token): void
    {
        $servers = $this->getAllServers();
        $this->save($servers, null, $token);
    }

    /**
     * Save servers to storage.
     */
    protected function save(Collection $servers, ?int $activeServerId = null, ?string $apiToken = null): void
    {
        if ($activeServerId === null) {
            $activeServerId = $this->getActiveServerId();
        }

        if ($apiToken === null) {
            $apiToken = $this->getApiToken();
        }

        $this->storage->write($this->path, [
            'active_server_id' => $activeServerId,
            'api_token' => $apiToken,
            'servers' => $servers->toArray(),
        ]);
    }
}
