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
                <div class="px-2 bg-blue-600 text-white font-bold">
                    🛳️ SHIPYARD CLI 
                </div>
                <div class="text-blue-400 font-bold">
<pre>
   _____ __  _____________  _____    ____  ____ 
  / ___// / / /  _/ __ \ \/ /   |  / __ \/ __ \
  \__ \/ /_/ // // /_/ /\  / /| | / /_/ / / / / 
 ___/ / __  // // ____/ / / ___ |/ _, _/ /_/ /  
/____/_/ /_/___/_/     /_/_/  |_/_/ |_|/_____/  
</pre>
                </div>
                <div class="text-gray-500 italic">
                    The ultimate VPS & Site Management Suite
                </div>
            </div>
HTML
        );
    }
}
