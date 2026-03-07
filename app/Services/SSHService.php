<?php

namespace App\Services;

use Symfony\Component\Process\Process;

class SSHService
{
    /**
     * Test connection to the server.
     */
    public function testConnection(array $server): bool
    {
        $command = $this->buildCommand($server, 'echo OK');
        $process = Process::fromShellCommandline($command);
        $process->run();

        return str_contains($process->getOutput(), 'OK');
    }

    /**
     * Build SSH command.
     */
    public function buildCommand(array $server, string $remoteCommand): string
    {
        $authType = $server['auth_type'] ?? 'key';

        if ($authType === 'password' && !empty($server['password'])) {
            return sprintf(
                'sshpass -p %s ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no %s@%s -p %d "%s"',
                escapeshellarg($server['password']),
                escapeshellarg($server['user']),
                escapeshellarg($server['host']),
                (int) $server['port'],
                addslashes($remoteCommand)
            );
        }

        return sprintf(
            'ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no -i %s %s@%s -p %d "%s"',
            escapeshellarg($server['private_key'] ?? '~/.ssh/id_rsa'),
            escapeshellarg($server['user']),
            escapeshellarg($server['host']),
            (int) $server['port'],
            addslashes($remoteCommand)
        );
    }
}
