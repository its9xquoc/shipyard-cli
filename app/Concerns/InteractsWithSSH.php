<?php

namespace App\Concerns;

trait InteractsWithSSH
{
    /**
     * Test SSH connection to the server.
     */
    protected function testConnection(array $server): bool
    {
        return $this->sshService->testConnection($server);
    }
}
