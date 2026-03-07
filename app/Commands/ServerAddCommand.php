<?php

namespace App\Commands;

use App\Repositories\ServerRepository;
use Illuminate\Console\Command;

use function Laravel\Prompts\confirm;
use function Laravel\Prompts\password;
use function Laravel\Prompts\select;
use function Laravel\Prompts\text;

class ServerAddCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'server:add';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Add a new VPS server';

    /**
     * Create a new command instance.
     */
    public function __construct(
        protected ServerRepository $repository
    ) {
        parent::__construct();
    }

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $name = text(
            label: 'Server name',
            placeholder: 'production',
            required: true
        );

        $host = text(
            label: 'Host IP/Domain',
            placeholder: '192.168.1.1',
            required: true
        );

        $port = text(
            label: 'SSH Port',
            default: '22',
            required: true,
            validate: fn (string $value) => is_numeric($value) ? null : 'Port must be a number'
        );

        $user = text(
            label: 'SSH User',
            default: 'root',
            required: true
        );

        $authType = select(
            label: 'Authentication method',
            options: [
                'key' => 'Identity File (Private Key)',
                'password' => 'Password (Not recommended for production)',
            ],
            default: 'key'
        );

        $privateKey = null;
        $serverPassword = null;

        if ($authType === 'key') {
            $privateKey = text(
                label: 'Private Key Path',
                default: '~/.ssh/id_rsa',
                required: true
            );
        } else {
            $serverPassword = password(
                label: 'SSH Password',
                placeholder: 'Enter your SSH password',
                required: true
            );
        }

        $deployUser = text(
            label: 'Deployment User Name',
            default: $name,
            required: true,
            hint: 'This user will be created during setup and used for web app deployment.'
        );

        if (confirm('Do you want to save this server?')) {
            $this->repository->addServer([
                'name' => $name,
                'host' => $host,
                'port' => (int) $port,
                'user' => $user,
                'auth_type' => $authType,
                'private_key' => $privateKey,
                'password' => $serverPassword,
                'deploy_user' => $deployUser,
            ]);

            $this->info('Server added successfully.');
        }

        return self::SUCCESS;
    }
}
