<?php

namespace App\Dto;

class ServerDto
{
    public function __construct(
        public ?int $id,
        public string $name,
        public string $host,
        public int $port,
        public string $user,
        public string $authType,
        public ?string $privateKey,
        public ?string $password,
        public string $deployUser,
        public ?string $phpVersion,
        public ?string $dbRootPass,
        public ?string $updatedAt,
        public array $sites,
    ) {}

    public static function fromArray(array $data): self
    {
        return new self(
            id: isset($data['id']) ? (int) $data['id'] : null,
            name: $data['name'] ?? '',
            host: $data['host'] ?? '',
            port: (int) ($data['port'] ?? 22),
            user: $data['user'] ?? 'root',
            authType: $data['auth_type'] ?? ($data['authType'] ?? 'key'),
            privateKey: $data['private_key'] ?? ($data['sshKeyPath'] ?? '~/.ssh/id_rsa'),
            password: $data['password'] ?? null,
            deployUser: $data['deploy_user'] ?? ($data['deploymentUser'] ?? 'deploy'),
            phpVersion: $data['php_version'] ?? ($data['phpVersion'] ?? null),
            dbRootPass: $data['db_root_pass'] ?? ($data['databaseRootPassword'] ?? null),
            updatedAt: $data['updated_at'] ?? null,
            sites: $data['sites'] ?? [],
        );
    }

    public static function fromList(array $list): array
    {
        return array_map(fn ($data) => self::fromArray($data), $list);
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'host' => $this->host,
            'port' => $this->port,
            'user' => $this->user,
            'auth_type' => $this->authType,
            'private_key' => $this->privateKey,
            'password' => $this->password,
            'deploy_user' => $this->deployUser,
            'php_version' => $this->phpVersion,
            'db_root_pass' => $this->dbRootPass,
            'updated_at' => $this->updatedAt,
            'sites' => $this->sites,
        ];
    }
}
