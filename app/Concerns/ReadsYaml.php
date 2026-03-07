<?php

namespace App\Concerns;

use Symfony\Component\Yaml\Yaml;

trait ReadsYaml
{
    /**
     * Read YAML from path.
     */
    public function readYaml(string $path): array
    {
        if (!file_exists($path)) {
            return [];
        }

        return Yaml::parseFile($path) ?: [];
    }
}
