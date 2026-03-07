<?php

namespace App\Repositories;

use App\Dto\ServerDto;
use App\Dto\SiteDto;
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
     * Get all servers as a collection of normalized arrays.
     */
    public function getAllServers(): Collection
    {
        $data = $this->readData();
        $servers = $this->normalizeServers($data['servers'] ?? []);
        $sites = $this->normalizeSites($data['sites'] ?? []);

        return collect($servers)->map(function (array $server) use ($sites) {
            $serverSites = collect($sites)
                ->filter(function (array $site) use ($server) {
                    $siteServerKey = (string) ($site['server_key'] ?? '');
                    $siteServerId = isset($site['server_id']) ? (int) $site['server_id'] : null;

                    return ($siteServerId !== null && $siteServerId === (int) $server['id'])
                        || ($siteServerKey !== '' && $siteServerKey === (string) $server['name']);
                })
                ->map(fn (array $site) => $this->cleanSiteForServer($site))
                ->values()
                ->toArray();

            if (empty($serverSites) && !empty($server['sites']) && is_array($server['sites'])) {
                $serverSites = array_values($server['sites']);
            }

            $server['sites'] = $serverSites;

            return $server;
        });
    }

    /**
     * Add a new server.
     */
    public function addServer(array|ServerDto $server): void
    {
        $payload = $server instanceof ServerDto ? $server->toArray() : $server;
        $servers = $this->getAllServers();

        $payload['id'] = isset($payload['id']) ? (int) $payload['id'] : (($servers->max('id') ?? 0) + 1);
        $normalized = ServerDto::fromArray($payload)->toArray();

        // Do not persist embedded sites in server records.
        unset($normalized['sites']);

        $servers = $servers->map(function (array $item) {
            unset($item['sites']);

            return $item;
        });

        $servers->push($normalized);

        $this->save($servers);
    }

    /**
     * Update an existing server by numeric ID or server name.
     */
    public function updateServer(int|string $serverKey, array $updatedData): void
    {
        $servers = $this->getAllServers();
        $target = $this->resolveServer($servers, $serverKey);

        if (!$target) {
            return;
        }

        $sites = $updatedData['sites'] ?? null;
        unset($updatedData['sites']);

        $updatedServers = $servers->map(function (array $server) use ($target, $updatedData) {
            if ((int) $server['id'] !== (int) $target['id']) {
                return $server;
            }

            return array_merge($server, $updatedData);
        });

        $this->save($updatedServers);

        if (is_array($sites)) {
            $this->syncSitesForServer((int) $target['id'], (string) $target['name'], $sites);
        }
    }

    /**
     * Delete server and associated sites.
     */
    public function deleteServer(int $id): void
    {
        $servers = $this->getAllServers();
        $target = $servers->firstWhere('id', $id);

        $remaining = $servers->reject(fn (array $server) => (int) $server['id'] === $id)->values();
        $this->save($remaining);

        if ($target) {
            $this->deleteSitesForServer((int) $id, (string) $target['name']);
        }
    }

    /**
     * Find server by ID.
     */
    public function findById(int $id): ?array
    {
        return $this->getAllServers()->firstWhere('id', $id);
    }

    /**
     * Get active server ID.
     */
    public function getActiveServerId(): ?int
    {
        $data = $this->readData();

        return isset($data['active_server_id']) ? (int) $data['active_server_id'] : null;
    }

    /**
     * Set active server ID.
     */
    public function setActiveServerId(int $id): void
    {
        $servers = $this->getAllServers();
        $this->save($servers, $id);
    }

    /**
     * Get API token.
     */
    public function getApiToken(): ?string
    {
        $data = $this->readData();

        return $data['api_token'] ?? null;
    }

    /**
     * Set API token.
     */
    public function setApiToken(string $token): void
    {
        $servers = $this->getAllServers();
        $this->save($servers, null, $token);
    }

    /**
     * Save servers and preserve side channels (sites, active server, token).
     */
    protected function save(Collection $servers, ?int $activeServerId = null, ?string $apiToken = null): void
    {
        $data = $this->readData();

        if ($activeServerId === null) {
            $activeServerId = isset($data['active_server_id']) ? (int) $data['active_server_id'] : null;
        }

        if ($apiToken === null) {
            $apiToken = $data['api_token'] ?? null;
        }

        $serversPayload = $servers
            ->map(function (array $server) {
                unset($server['sites']);

                return ServerDto::fromArray($server)->toArray();
            })
            ->values()
            ->toArray();

        $sitesPayload = $this->normalizeSites($data['sites'] ?? []);

        if (empty($sitesPayload)) {
            $sitesPayload = $this->extractLegacySitesFromServers($servers);
        }

        $this->storage->write($this->path, [
            'active_server_id' => $activeServerId,
            'api_token' => $apiToken,
            'servers' => $serversPayload,
            'sites' => $sitesPayload,
        ]);
    }

    protected function readData(): array
    {
        return $this->storage->read($this->path);
    }

    protected function normalizeServers(array $servers): array
    {
        // Accept both list and keyed-map input formats.
        if (!empty($servers) && array_keys($servers) !== range(0, count($servers) - 1)) {
            $servers = array_values($servers);
        }

        $nextId = 1;

        return array_map(function (array $server) use (&$nextId) {
            if (!isset($server['id'])) {
                $server['id'] = $nextId;
            }
            $nextId = max($nextId, (int) $server['id'] + 1);

            return ServerDto::fromArray($server)->toArray();
        }, $servers);
    }

    protected function normalizeSites(array $sites): array
    {
        if (!empty($sites) && array_keys($sites) !== range(0, count($sites) - 1)) {
            $sites = array_values($sites);
        }

        return array_map(fn (array $site) => SiteDto::fromArray($site)->toArray(), $sites);
    }

    protected function resolveServer(Collection $servers, int|string $serverKey): ?array
    {
        if (is_int($serverKey) || ctype_digit((string) $serverKey)) {
            return $servers->firstWhere('id', (int) $serverKey);
        }

        return $servers->first(fn (array $server) => (string) $server['name'] === (string) $serverKey);
    }

    protected function cleanSiteForServer(array $site): array
    {
        unset($site['server_key'], $site['server_id']);

        return $site;
    }

    protected function syncSitesForServer(int $serverId, string $serverName, array $sites): void
    {
        $data = $this->readData();
        $existing = $this->normalizeSites($data['sites'] ?? []);

        $filtered = array_values(array_filter(
            $existing,
            fn (array $site) => !(
                ((isset($site['server_id']) ? (int) $site['server_id'] : null) === $serverId)
                || ((string) ($site['server_key'] ?? '') === $serverName)
            )
        ));

        $maxId = (int) collect($filtered)->max('id');
        $nextId = $maxId > 0 ? $maxId + 1 : 1;

        $payload = array_map(function (array $site) use ($serverId, $serverName, &$nextId) {
            $site['id'] = isset($site['id']) ? (int) $site['id'] : $nextId++;
            $site['server_id'] = $serverId;
            $site['server_key'] = $serverName;

            return SiteDto::fromArray($site)->toArray();
        }, $sites);

        $data['sites'] = array_values(array_merge($filtered, $payload));
        $this->storage->write($this->path, $data);
    }

    protected function deleteSitesForServer(int $serverId, string $serverName): void
    {
        $data = $this->readData();
        $sites = $this->normalizeSites($data['sites'] ?? []);

        $data['sites'] = array_values(array_filter(
            $sites,
            fn (array $site) => !(
                ((isset($site['server_id']) ? (int) $site['server_id'] : null) === $serverId)
                || ((string) ($site['server_key'] ?? '') === $serverName)
            )
        ));

        $this->storage->write($this->path, $data);
    }

    protected function extractLegacySitesFromServers(Collection $servers): array
    {
        $result = [];
        $nextId = 1;

        foreach ($servers as $server) {
            $legacySites = $server['sites'] ?? [];
            if (!is_array($legacySites)) {
                continue;
            }

            foreach ($legacySites as $site) {
                if (!is_array($site)) {
                    continue;
                }

                $site['id'] = isset($site['id']) ? (int) $site['id'] : $nextId++;
                $site['server_id'] = (int) ($server['id'] ?? 0);
                $site['server_key'] = (string) ($server['name'] ?? '');
                $result[] = SiteDto::fromArray($site)->toArray();
            }
        }

        return $result;
    }
}
