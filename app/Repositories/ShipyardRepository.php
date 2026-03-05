<?php

namespace App\Repositories;

use Exception;
use GuzzleHttp;
use Laravel\Forge\Exceptions\NotFoundException;

/**
 * @mixin \App\Clients\Shipyard
 */
class ShipyardRepository
{
    /**
     * The configuration repository.
     *
     * @var \App\Repositories\ConfigRepository
     */
    protected $config;

    /**
     * The client.
     *
     * @var \Laravel\Forge\Shipyard
     */
    protected $client;

    /**
     * Creates a new repository instance.
     *
     * @param  \App\Repositories\ConfigRepository  $config
     * @param  \Laravel\Forge\Shipyard  $client
     * @return void
     */
    public function __construct($config, $client)
    {
        $this->config = $config;
        $this->client = $client;
    }

    /**
     * Sets the client.
     *
     * @param  \Laravel\Forge\Shipyard  $client
     * @return $this
     */
    public function setClient($client)
    {
        $this->client = $client;

        return $this;
    }

    /**
     * Pass other method calls down to the underlying client.
     *
     * @param  string  $method
     * @param  array  $parameters
     * @return mixed
     */
    public function __call($method, $parameters)
    {
        $this->ensureApiToken();
        $this->ensureCurrentTeamIsSet();

        try {
            return $this->client->{$method}(...$parameters);
        } catch (Exception $e) {
            if ($e instanceof NotFoundException) {
                abort(1, $e->getMessage());
            }

            throw $e;
        }
    }

    /**
     * Ensure an api token is defined on the client.
     *
     * @return void
     */
    protected function ensureApiToken()
    {
        $token = $this->config->get('token', $_SERVER['SHIPYARD_API_TOKEN'] ?? getenv('SHIPYARD_API_TOKEN') ?: null);

        abort_if($token == null, 1, 'Please authenticate using the \'login\' command before proceeding.');

        $guzzle = new GuzzleHttp\Client([
            'base_uri' => isset($_SERVER['SHIPYARD_API_BASE']) ? $_SERVER['SHIPYARD_API_BASE'] : 'https://shipyard.laravel.com/api/v1/',
            'http_errors' => false,
            'headers' => [
                'Authorization' => 'Bearer '.$token,
                'Accept' => 'application/json',
                'Content-Type' => 'application/json',
                'User-Agent' => 'Laravel\Forge CLI/v'.config('app.version'),
            ],
        ]);

        $this->client->setApiKey($token, $guzzle);
    }

    /**
     * Ensure the current team is set in the configuration file.
     *
     * @return void
     */
    protected function ensureCurrentTeamIsSet()
    {
        if (! $this->config->get('server', false)) {
            $server = collect($this->client->servers())->first();

            abort_if($server == null, 1, 'Please create a server first.');

            $this->config->set('server', $server->id);
        }
    }
}
