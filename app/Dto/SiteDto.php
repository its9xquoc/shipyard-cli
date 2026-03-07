<?php

namespace App\Dto;

class SiteDto
{
    public function __construct(
        public ?int $id,
        public string $serverKey,
        public ?int $serverId,
        public string $name,
        public string $domain,
        public ?string $email,
        public string $type,
        public array $aliases,
        public string $path,
        public string $phpVersion,
        public ?string $databaseName,
        public ?string $databaseUser,
        public ?string $databasePassword,
        public ?string $createdAt,
        public ?string $updatedAt,
    ) {}

    public static function fromArray(array $data): self
    {
        return new self(
            id: isset($data['id']) ? (int) $data['id'] : null,
            serverKey: $data['server_key'] ?? ($data['serverKey'] ?? ''),
            serverId: isset($data['server_id']) ? (int) $data['server_id'] : null,
            name: $data['name'] ?? '',
            domain: $data['domain'] ?? '',
            email: $data['email'] ?? null,
            type: $data['type'] ?? 'default',
            aliases: $data['aliases'] ?? [],
            path: $data['path'] ?? ($data['rootDirectory'] ?? '/var/www/html'),
            phpVersion: $data['php_version'] ?? ($data['phpVersion'] ?? ''),
            databaseName: $data['database'] ?? ($data['database_name'] ?? ($data['databaseName'] ?? null)),
            databaseUser: $data['db_user'] ?? ($data['database_user'] ?? ($data['databaseUser'] ?? null)),
            databasePassword: $data['db_password'] ?? ($data['database_password'] ?? ($data['databasePassword'] ?? null)),
            createdAt: $data['created_at'] ?? null,
            updatedAt: $data['updated_at'] ?? null,
        );
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'server_key' => $this->serverKey,
            'server_id' => $this->serverId,
            'name' => $this->name,
            'domain' => $this->domain,
            'email' => $this->email,
            'type' => $this->type,
            'aliases' => $this->aliases,
            'path' => $this->path,
            'php_version' => $this->phpVersion,
            'database' => $this->databaseName,
            'db_user' => $this->databaseUser,
            'db_password' => $this->databasePassword,
            'created_at' => $this->createdAt,
            'updated_at' => $this->updatedAt,
        ];
    }
}
