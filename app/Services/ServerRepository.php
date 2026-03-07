<?php

namespace App\Services;

use Illuminate\Support\Collection;

class ServerRepository
{
    protected string $path;

    public function __construct(
        protected YamlStorage $storage
    ) {
        $this->path = config('vps-manager.storage_path');
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
     * Save servers to storage.
     */
    protected function save(Collection $servers): void
    {
        $this->storage->write($this->path, ['servers' => $servers->toArray()]);
    }
}
