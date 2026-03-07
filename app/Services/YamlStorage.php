<?php

namespace App\Services;

use Symfony\Component\Yaml\Yaml;

class YamlStorage
{
    /**
     * Read YAML file and return as array.
     */
    public function read(string $path): array
    {
        if (!file_exists($path)) {
            return [];
        }

        return Yaml::parseFile($path) ?: [];
    }

    /**
     * Write array to YAML file.
     */
    public function write(string $path, array $data): void
    {
        $yaml = Yaml::dump($data, 4, 2);
        file_put_contents($path, $yaml);
    }
}
