<?php

namespace App\Repositories;

use App\Services\YamlStorage;
use Illuminate\Support\Collection;

class CredentialsRepository
{
    protected string $dir;

    public function __construct(
        protected YamlStorage $storage
    ) {
        $this->dir = dirname(config('shipyard.storage_path')) . '/credentials';
    }

    /**
     * Save credentials for a server, overwriting any existing entry.
     */
    public function save(string $serverSlug, array $credentials): string
    {
        if (!is_dir($this->dir)) {
            mkdir($this->dir, 0700, true);
        }

        $path = $this->pathFor($serverSlug);
        $this->storage->write($path, $credentials);
        chmod($path, 0600);

        return $path;
    }

    /**
     * Get credentials for a server by slug.
     */
    public function get(string $serverSlug): array
    {
        return $this->storage->read($this->pathFor($serverSlug));
    }

    /**
     * Get all stored credentials as a keyed Collection (slug => data).
     */
    public function all(): Collection
    {
        if (!is_dir($this->dir)) {
            return collect();
        }

        return collect(glob($this->dir . '/*.yaml'))
            ->mapWithKeys(function (string $file) {
                $slug = basename($file, '.yaml');

                return [$slug => $this->storage->read($file)];
            });
    }

    /**
     * Check whether credentials exist for the given server slug.
     */
    public function exists(string $serverSlug): bool
    {
        return file_exists($this->pathFor($serverSlug));
    }

    /**
     * Delete credentials for a server.
     */
    public function delete(string $serverSlug): void
    {
        $path = $this->pathFor($serverSlug);

        if (file_exists($path)) {
            unlink($path);
        }
    }

    /**
     * Resolve the absolute file path for a server slug.
     */
    protected function pathFor(string $serverSlug): string
    {
        $slug = preg_replace('/[^a-zA-Z0-9_-]/', '_', $serverSlug);

        return $this->dir . '/' . $slug . '.yaml';
    }
}
