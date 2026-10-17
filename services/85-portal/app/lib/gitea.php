<?php
// Gitea, reached on the internal network (GITEA_API_URL, set in compose.yaml). Every request is made with the
// competitor's own credentials: they only see and change what they could in Gitea, no admin token needed.

// Call the Gitea API: [HTTP status, decoded JSON body], status 0 when Gitea does not answer
function gitea_request(string $method, string $path, string $username, string $password, ?array $body = null): array
{
    $headers = ['Authorization: Basic ' . base64_encode($username . ':' . $password)];
    if ($body !== null) {
        $headers[] = 'Content-Type: application/json';
    }
    $context = stream_context_create(['http' => [
        'method' => $method,
        'header' => implode("\r\n", $headers),
        'content' => $body === null ? '' : json_encode($body),
        'timeout' => $method === 'GET' ? 3 : 15,
        'ignore_errors' => true,
    ]]);
    $response = @file_get_contents(getenv('GITEA_API_URL') . $path, false, $context);
    if ($response === false || !preg_match('#^HTTP/\S+ (\d{3})#', $http_response_header[0] ?? '', $match)) {
        return [0, null];
    }
    return [(int) $match[1], json_decode($response, true)];
}

// Names of the repositories owned by the competitor, private ones included. Null when Gitea does not answer.
function owned_repositories(string $username, string $password): ?array
{
    [$status, $repositories] = gitea_request('GET', '/user/repos?limit=100', $username, $password);
    if ($status !== 200) {
        return null;
    }
    $names = [];
    foreach ($repositories ?? [] as $repository) {
        if (($repository['owner']['login'] ?? '') === $username) {
            $names[] = $repository['name'];
        }
    }
    return $names;
}

// Template repositories of the "frameworks" organization, limited to $allowed (null: all of them, as
// import-frameworks imports everything without allowed_frameworks). Null when Gitea does not answer.
function framework_templates(string $username, string $password, ?array $allowed): ?array
{
    [$status, $repositories] = gitea_request('GET', '/orgs/frameworks/repos?limit=100', $username, $password);
    if ($status !== 200) {
        return null;
    }
    $names = [];
    foreach ($repositories ?? [] as $repository) {
        if (($repository['template'] ?? false) && ($allowed === null || in_array($repository['name'], $allowed, true))) {
            $names[] = $repository['name'];
        }
    }
    sort($names);
    return $names;
}

// Create the private repository <username>/<name> from the template frameworks/<template>: null when done,
// otherwise the reason
function create_repository_from_template(string $username, string $password, string $template, string $name): ?string
{
    [$status, $body] = gitea_request('POST', '/repos/frameworks/' . rawurlencode($template) . '/generate',
        $username, $password, ['owner' => $username, 'name' => $name, 'private' => true, 'git_content' => true]);
    return match (true) {
        $status === 201 => null,
        $status === 0 => 'Gitea ne répond pas.',
        $status === 409 => 'Ce dépôt existe déjà.',
        default => 'Gitea a refusé (' . $status . ')' . (isset($body['message']) ? ' : ' . $body['message'] : '.'),
    };
}

// Delete the repository <username>/<name>: null when done, otherwise the reason
function delete_repository(string $username, string $password, string $name): ?string
{
    [$status, $body] = gitea_request('DELETE', '/repos/' . rawurlencode($username) . '/' . rawurlencode($name),
        $username, $password);
    return match (true) {
        $status === 204 => null,
        $status === 0 => 'Gitea ne répond pas.',
        $status === 404 => "Ce dépôt n'existe pas.",
        default => 'Gitea a refusé (' . $status . ')' . (isset($body['message']) ? ' : ' . $body['message'] : '.'),
    };
}
