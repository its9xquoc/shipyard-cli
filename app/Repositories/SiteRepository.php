<?php

namespace App\Repositories;

use App\Dto\SiteDto;
use App\Services\YamlStorage;

class SiteRepository
{
    protected string $path;

    public function __construct(
        protected YamlStorage $storage
    ) {
        $this->path = config('shipyard.storage_path');
    }

    public function getAllSites(): array
    {
        $data = $this->storage->read($this->path);

        return $this->normalizeSites($data['sites'] ?? []);
    }

    public function getSitesByServer(string|int $serverKeyOrId): array
    {
        return array_values(array_filter(
            $this->getAllSites(),
            function (array $site) use ($serverKeyOrId) {
                if (is_int($serverKeyOrId) || ctype_digit((string) $serverKeyOrId)) {
                    return (int) ($site['server_id'] ?? 0) === (int) $serverKeyOrId;
                }

                return (string) ($site['server_key'] ?? '') === (string) $serverKeyOrId;
            }
        ));
    }

    public function addSite(array|SiteDto $site): void
    {
        $sites = $this->getAllSites();
        $payload = $site instanceof SiteDto ? $site->toArray() : $site;

        $payload['id'] = isset($payload['id'])
            ? (int) $payload['id']
            : (($sites ? max(array_column($sites, 'id')) : 0) + 1);

        $sites[] = SiteDto::fromArray($payload)->toArray();
        $this->save($sites);
    }

    public function updateSite(int $id, array $updatedData): void
    {
        $sites = $this->getAllSites();

        foreach ($sites as &$site) {
            if ((int) $site['id'] === $id) {
                $site = SiteDto::fromArray(array_merge($site, $updatedData))->toArray();
                break;
            }
        }

        $this->save($sites);
    }

    public function deleteSite(int $id): void
    {
        $sites = $this->getAllSites();
        $sites = array_values(array_filter($sites, fn (array $site) => (int) $site['id'] !== $id));
        $this->save($sites);
    }

    public function findById(int $id): ?array
    {
        foreach ($this->getAllSites() as $site) {
            if ((int) $site['id'] === $id) {
                return $site;
            }
        }

        return null;
    }

    public function replaceSitesForServer(string $serverKey, int $serverId, array $sites): void
    {
        $allSites = $this->getAllSites();

        $remaining = array_values(array_filter(
            $allSites,
            fn (array $site) => !(
                ((int) ($site['server_id'] ?? 0) === $serverId)
                || ((string) ($site['server_key'] ?? '') === $serverKey)
            )
        ));

        $maxId = $remaining ? max(array_column($remaining, 'id')) : 0;
        foreach ($sites as $site) {
            $maxId++;
            $payload = SiteDto::fromArray(array_merge($site, [
                'id' => $site['id'] ?? $maxId,
                'server_key' => $serverKey,
                'server_id' => $serverId,
            ]))->toArray();

            $remaining[] = $payload;
        }

        $this->save($remaining);
    }

    protected function save(array $sites): void
    {
        $data = $this->storage->read($this->path);
        $data['sites'] = array_values(array_map(
            fn (array $site) => SiteDto::fromArray($site)->toArray(),
            $sites
        ));

        $this->storage->write($this->path, $data);
    }

    protected function normalizeSites(array $sites): array
    {
        if (!empty($sites) && array_keys($sites) !== range(0, count($sites) - 1)) {
            $sites = array_values($sites);
        }

        return array_values(array_map(
            fn (array $site) => SiteDto::fromArray($site)->toArray(),
            $sites
        ));
    }
}
