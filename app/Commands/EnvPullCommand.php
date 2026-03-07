<?php

namespace App\Commands;

use App\Concerns\InteractsWithServers;
use App\Concerns\InteractsWithSSH;
use App\Repositories\ServerRepository;
use App\Services\SSHService;
use Illuminate\Console\Command;

use function Laravel\Prompts\select;

class EnvPullCommand extends Command
{
    use InteractsWithServers, InteractsWithSSH;

    protected $signature = 'env:pull {site? : The name of the site} {filename? : The environment file}';

    protected $description = 'Pull down an environment file for a given site';

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
        $filename = $this->argument('filename') ?? '.env';

        $sites = $server['sites'] ?? [];

        if (empty($siteName) && !empty($sites)) {
            $siteOptions = collect($sites)->pluck('name', 'name')->toArray();
            $siteName = select(
                'Select a site to pull environment from:',
                $siteOptions
            );
        }

        if (empty($siteName)) {
            $this->error('No site selected or found.');

            return self::FAILURE;
        }

        $site = (array) collect($sites)->firstWhere('name', $siteName);
        if (!$site) {
            $this->error("Site '{$siteName}' not found on server.");

            return self::FAILURE;
        }

        $remotePath = $site['path'] . '/' . $filename;
        $localPath = getcwd() . '/' . $filename;

        // Build cat command to fetch content
        $remoteCmd = 'cat ' . escapeshellarg($remotePath);
        $sshCmd = $this->sshService->buildCommand($server, $remoteCmd);

        $this->components->info("Pulling {$filename} from '{$siteName}'...");

        $content = shell_exec($sshCmd);

        if ($content === null) {
            $this->error('Failed to pull environment file. Check if file exists on server.');

            return self::FAILURE;
        }

        file_put_contents($localPath, $content);

        $this->info("Environment file pulled to: {$localPath}");

        return self::SUCCESS;
    }
}
