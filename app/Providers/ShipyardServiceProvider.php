<?php

namespace App\Providers;

use App\Clients\Shipyard;
use App\Repositories\ConfigRepository;
use App\Repositories\ShipyardRepository;
use Illuminate\Support\ServiceProvider;

class ShipyardServiceProvider extends ServiceProvider
{
    /**
     * Bootstrap any application services.
     *
     * @return void
     */
    public function boot()
    {
        //
    }

    /**
     * Register any application services.
     *
     * @return void
     */
    public function register()
    {
        $this->app->singleton(ShipyardRepository::class, function () {
            $config = resolve(ConfigRepository::class);
            $token = $config->get('token', $_SERVER['SHIPYARD_API_TOKEN'] ?? getenv('SHIPYARD_API_TOKEN') ?: null);

            $client = new Shipyard($token);

            return new ShipyardRepository($config, $client);
        });
    }
}
