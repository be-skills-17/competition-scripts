<?php
// Everything shown to a logged-in competitor, computed here so the templates only display values

const HIDDEN = '••••••••';

function competitor_view(array $portal, string $username): array
{
    $competitor = $portal['competitors'][$username];
    $repositories = owned_repositories($username, $competitor['password']);

    $modules = [];
    foreach ($competitor['modules'] as $module) {
        $state = $repositories === null ? 'unknown'
            : (in_array($module['name'], $repositories, true) ? 'created' : 'missing');
        [$cloneShown, $cloneCopied] = clone_urls($module['repository'], $username, $competitor['password']);
        $modules[] = $module + [
            'state' => $state,
            // Nothing to visit or clone before the repository exists (unknown state: don't block)
            'available' => $state !== 'missing',
            'clone_shown' => $cloneShown,
            'clone_copied' => $cloneCopied,
        ];
    }

    return [
        'username' => $username,
        'name' => $competitor['name'],
        'password' => $competitor['password'],
        'modules' => $modules,
        'apis' => $competitor['apis'],
    ];
}

// Repository URL with the credentials, ready for "git clone": [shown (password hidden), copied (complete)]
function clone_urls(string $repository, string $username, string $password): array
{
    $with = fn(string $credentials) => preg_replace('#^(https?://)#', '${1}' . $credentials . '@', $repository);
    $user = rawurlencode($username);
    return [$with($user . ':' . HIDDEN), $with($user . ':' . rawurlencode($password))];
}
