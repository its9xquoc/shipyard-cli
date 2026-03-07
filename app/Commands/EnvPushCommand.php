<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

use function Laravel\Prompts\confirm;
use function Laravel\Prompts\select;

class EnvPushCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'env:push {site? : The name of the site} {filename? : The local environment file}';

    protected $description = 'Push up an environment file for a given site';

    public function __construct(
        protected ServerRepository $repository,
        protected SSHService $sshService
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $server = $this->chooseServer();
        $siteName = $this->argument('site');
        $localFilename = $this->argument('filename') ?? '.env';

        $sites = $server['sites'] ?? [];

        if (empty($siteName) && !empty($sites)) {
            $siteOptions = collect($sites)->pluck('name', 'name')->toArray();
            $appName = select(
                'Select a site to push environment to:',
                $siteOptions
            );
            $siteName = $appName;
        }

        if (empty($siteName)) {
            $this->error('No site selected or found.');

            return self::FAILURE;
        }

        $localPath = getcwd() . '/' . $localFilename;
        if (!file_exists($localPath)) {
            $this->error("Local environment file '{$localPath}' not found.");

            return self::FAILURE;
        }

        $site = (array) collect($sites)->firstWhere('name', $siteName);
        if (!$site) {
            $this->error("Site '{$siteName}' not found on server.");

            return self::FAILURE;
        }

        if (!confirm("Are you sure you want to push environment to '{$siteName}'? This will OVERWRITE existing file.")) {
            $this->info('Aborted.');

            return self::SUCCESS;
        }

        $remotePath = $site['path'] . '/.env';
        $content = file_get_contents($localPath);

        // Build remote command to write content
        $remoteCmd = 'cat > ' . escapeshellarg($remotePath);
        $sshCmd = $this->sshService->buildCommand($server, $remoteCmd);

        $this->components->info("Pushing environment to '{$siteName}'...");

        // Pass content via stdin
        $process = proc_open($sshCmd, [
            0 => ['pipe', 'r'],
            1 => STDOUT,
            2 => STDERR,
        ], $pipes);

        if (is_resource($process)) {
            fwrite($pipes[0], $content);
            fclose($pipes[0]);
            $exitCode = proc_close($process);
        } else {
            $this->error('Failed to execute SSH process.');

            return self::FAILURE;
        }

        if ($exitCode === 0) {
            $this->info("Environment file pushed to: {$remotePath}");

            return self::SUCCESS;
        }

        $this->error("Failed to push environment file. Exit code: {$exitCode}");

        return self::FAILURE;
    }
}
