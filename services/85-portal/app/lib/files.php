<?php
// Files provided to every competitor (subjects, assets...): config/files, mounted read-only (see compose.yaml)
// and listed on each request, so a file dropped there shows at once. Downloaded with public/download.php.

const FILES_DIR = '/etc/portal/files';

// Regular files of config/files, sorted by name: [{name, size}]. Hidden files (.gitkeep) and folders are left out.
function provided_files(): array
{
    $files = [];
    foreach (@scandir(FILES_DIR) ?: [] as $name) {
        $path = FILES_DIR . '/' . $name;
        if ($name[0] !== '.' && is_file($path)) {
            $files[] = ['name' => $name, 'size' => filesize($path)];
        }
    }
    usort($files, fn(array $a, array $b) => strnatcasecmp($a['name'], $b['name']));
    return $files;
}

// Path of a provided file, null when the name is not one of them: only names listed by provided_files() are
// served, so "../" or a hidden file can never be reached
function provided_file_path(string $name): ?string
{
    return in_array($name, array_column(provided_files(), 'name'), true) ? FILES_DIR . '/' . $name : null;
}

function human_size(int $bytes): string
{
    $units = ['o', 'Ko', 'Mo', 'Go'];
    $unit = 0;
    while ($bytes >= 1024 ** ($unit + 1) && $unit < count($units) - 1) {
        $unit++;
    }
    return $unit === 0 ? "$bytes o" : number_format($bytes / 1024 ** $unit, 1, ',', ' ') . ' ' . $units[$unit];
}
