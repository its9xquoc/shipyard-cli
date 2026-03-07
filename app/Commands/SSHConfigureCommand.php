<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

use function Laravel\Prompts\text;

class SSHConfigureCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'ssh:configure {--key= : The path to the public key} {--name= : The name for the key}';

    protected $description = 'Add an SSH key to the server';

    public function __construct(
        protected ServerRepository $repository,
        protected SSHService $sshService
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $server = $this->chooseServer();
        $keyPath = $this->option('key');

        if (empty($keyPath)) {
            $keyPath = text('Enter path to public key:', default: '~/.ssh/id_rsa.pub', required: true);
        }

        $keyPath = str_replace('~', getenv('HOME'), $keyPath);

        if (!file_exists($keyPath)) {
            $this->error("Key file not found at: {$keyPath}");

            return self::FAILURE;
        }

        $publicKey = trim(file_get_contents($keyPath));
        $keyName = $this->option('name') ?? basename($keyPath);

        // Build command to append key to authorized_keys
        $remoteCmd = 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo ' . escapeshellarg($publicKey . ' # ' . $keyName) . ' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys';

        $sshCmd = $this->sshService->buildCommand($server, $remoteCmd);

        $this->components->info("Adding SSH key '{$keyName}' to '{$server['name']}' ({$server['host']})...");

        passthru($sshCmd, $exitCode);

        if ($exitCode === 0) {
            $this->components->success('SSH key configured successfully.');
        }

        return $exitCode;
    }
}
