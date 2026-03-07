<?php

namespace App\Concerns;

use Symfony\Component\Yaml\Yaml;

trait WritesYaml
{
    /**
     * Write data to YAML path.
     */
    public function writeYaml(string $path, array $data): void
    {
        $yaml = Yaml::dump($data, 4, 2);
        file_put_contents($path, $yaml);
    }
}
