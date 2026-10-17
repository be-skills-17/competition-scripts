<?php
// Documentation of the provided APIs (Swagger UI), for logged-in competitors:
//   /api-docs.php              the page, one tab per documented API
//   /api-docs.php?spec=<name>  the API's openapi.json, pointing to the competitor's own instance

require dirname(__DIR__) . '/app/bootstrap.php';

$portal = load_portal_data();
$username = current_username($portal);
if ($username === null) {
    redirect('/');
}

$apis = array_values(array_filter($portal['competitors'][$username]['apis'], 'has_api_docs'));

if (isset($_GET['spec'])) {
    $api = current(array_filter($apis, fn(array $api) => $api['name'] === $_GET['spec']));
    $spec = $api === false ? null : api_spec($api);
    header('Content-Type: application/json');
    header('Cache-Control: no-store');
    if ($spec === null) {
        http_response_code(404);
        exit(json_encode(['error' => 'Documentation introuvable']));
    }
    exit(json_encode($spec, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
}

render('api-docs', ['apis' => $apis]);
