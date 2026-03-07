<?php

namespace App\Concerns;

use function Termwind\render;

trait DisplaysLogo
{
    /**
     * Display the Shipyard ASCII logo with premium styling.
     */
    protected function displayLogo(): void
    {
        render(<<<'HTML'
            <div class="py-1">
                <div class="flex space-x-1 mb-1">
                    <span class="px-2 bg-blue-600 text-white font-bold">🛳️</span>
                    <span class="px-2 bg-slate-800 text-blue-400 font-bold underline">SHIPYARD.ENGINE</span>
                </div>
                <div class="text-blue-500 font-bold">
<pre>
   _____ __    _                             __ 
  / ___// /_  (_)___  __  ______ ___________/ / 
  \__ \/ __ \/ / __ \/ / / / __ `/ ___/ __  /  
 ___/ / / / / / /_/ / /_/ / /_/ / /  / /_/ /   
/____/_/ /_/_/ .___/\__, /\__,_/_/   \__,_/    
            /_/    /____/                       
</pre>
                </div>
                <div class="flex space-x-2 text-gray-400">
                    <span class="italic">v1.8.3</span>
                    <span class="text-gray-600">|</span>
                    <span>The ultimate VPS & Site Management Suite</span>
                </div>
            </div>
HTML
        );
    }
}
