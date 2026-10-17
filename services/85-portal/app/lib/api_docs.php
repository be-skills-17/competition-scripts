<?php
// Documentation of the provided APIs: config/apis/<folder>/openapi.json, mounted read-only (see compose.yaml)
// and read on each request, so a change shows at once. Shown with Swagger UI by public/api-docs.php.

const API_DOCS_DIR = '/etc/portal/apis';

function api_spec_path(array $api): string
{
    return API_DOCS_DIR . '/' . $api['folder'] . '/openapi.json';
}

// False too while portal.json predates the folder (generated again by "recreate portal" or deploy-apis)
function has_api_docs(array $api): bool
{
    return isset($api['folder']) && is_file(api_spec_path($api));
}

// The API's OpenAPI description, its servers replaced by the competitor's own instance: "Try it out" calls
// their API and their database only. Null when the file is missing or not valid JSON.
function api_spec(array $api): ?array
{
    $spec = json_decode((string) @file_get_contents(api_spec_path($api)), true);
    if (!is_array($spec)) {
        return null;
    }
    $spec['servers'] = [['url' => rtrim($api['url'], '/'), 'description' => 'Votre instance']];
    return $spec;
}
