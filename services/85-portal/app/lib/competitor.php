<?php
// Everything shown to a logged-in competitor, computed here so the templates only display values

const HIDDEN = '••••••••';

// Word to type before deleting a repository
const DELETE_CONFIRMATION = 'Valider';

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
            // Repository page in Gitea: the clone URL without ".git"
            'web' => preg_replace('#\.git$#', '', $module['repository']),
            'clone_shown' => $cloneShown,
            'clone_copied' => $cloneCopied,
        ];
    }

    // Asked to Gitea only when a repository remains to be created
    $missing = in_array('missing', array_column($modules, 'state'), true);

    return [
        'username' => $username,
        'name' => $competitor['name'],
        'password' => $competitor['password'],
        'modules' => $modules,
        'templates' => $missing ? with_logos(framework_templates($username, $competitor['password'], $portal['frameworks'] ?? null)) : [],
        'apis' => array_map(fn(array $api) => $api + ['docs' => has_api_docs($api)], $competitor['apis']),
    ];
}

// Templates with their logo, public/img/frameworks/<name>.svg (null when there is none): [{name, logo}]
function with_logos(?array $templates): ?array
{
    if ($templates === null) {
        return null;
    }
    return array_map(function (string $name) {
        $path = '/img/frameworks/' . $name . '.svg';
        $exists = preg_match('/^[A-Za-z0-9._-]+$/', $name) && is_file($_SERVER['DOCUMENT_ROOT'] . $path);
        return ['name' => $name, 'logo' => $exists ? asset($path) : null];
    }, $templates);
}

// "Créer" / "Supprimer" of a module's repository (forms of sections/modules): the message to show
// ['ok' | 'error', text]
function module_action(array $portal, string $username, string $action, array $form): array
{
    $competitor = $portal['competitors'][$username];
    $module = $form['module'] ?? '';
    if (!in_array($module, array_column($competitor['modules'], 'name'), true)) {
        return ['error', 'Module inconnu.'];
    }

    if ($action === 'create_module') {
        $template = $form['template'] ?? '';
        $templates = framework_templates($username, $competitor['password'], $portal['frameworks'] ?? null);
        if ($templates === null) {
            return ['error', 'Gitea ne répond pas.'];
        }
        if (!in_array($template, $templates, true)) {
            return ['error', 'Choisissez un framework de la liste.'];
        }
        $failure = create_repository_from_template($username, $competitor['password'], $template, $module);
        return $failure === null ? ['ok', "Dépôt $module créé à partir du template $template."]
            : ['error', "Le dépôt $module n'a pas été créé : $failure"];
    }

    // delete_module: the competitor typed the confirmation word, as on GitHub
    if (($form['confirm'] ?? '') !== DELETE_CONFIRMATION) {
        return ['error', 'Tapez « ' . DELETE_CONFIRMATION . ' » pour confirmer la suppression.'];
    }
    $failure = delete_repository($username, $competitor['password'], $module);
    return $failure === null ? ['ok', "Dépôt $module supprimé."]
        : ['error', "Le dépôt $module n'a pas été supprimé : $failure"];
}

// Repository URL with the credentials, ready for "git clone": [shown (password hidden), copied (complete)]
function clone_urls(string $repository, string $username, string $password): array
{
    $with = fn(string $credentials) => preg_replace('#^(https?://)#', '${1}' . $credentials . '@', $repository);
    $user = rawurlencode($username);
    return [$with($user . ':' . HIDDEN), $with($user . ':' . rawurlencode($password))];
}
