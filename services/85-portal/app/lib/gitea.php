<?php
// Gitea, reached on the internal network (GITEA_API_URL, set in compose.yaml)

// Names of the repositories owned by the competitor, asked with their own credentials (they see their private
// repositories, no admin token needed). Null when Gitea does not answer.
function owned_repositories(string $username, string $password): ?array
{
    $context = stream_context_create(['http' => [
        'header' => 'Authorization: Basic ' . base64_encode($username . ':' . $password),
        'timeout' => 3,
        'ignore_errors' => true,
    ]]);
    $body = @file_get_contents(getenv('GITEA_API_URL') . '/user/repos?limit=100', false, $context);
    if ($body === false || !str_contains($http_response_header[0] ?? '', ' 200 ')) {
        return null;
    }
    $names = [];
    foreach (json_decode($body, true) ?? [] as $repository) {
        if (($repository['owner']['login'] ?? '') === $username) {
            $names[] = $repository['name'];
        }
    }
    return $names;
}
