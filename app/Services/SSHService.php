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
        return sprintf(
            'ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no -i %s %s@%s -p %d "%s"',
            escapeshellarg($server['private_key']),
            escapeshellarg($server['user']),
            escapeshellarg($server['host']),
            (int) $server['port'],
            addslashes($remoteCommand)
        );
    }
}
