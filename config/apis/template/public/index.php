<?php
// Template API in native PHP. To create an API: copy this folder to config/apis/<name>/,
// edit api.json ("enabled": true, "name", "host"), then run: sudo ./competition.sh deploy-apis
//
// Environment variables set for every instance:
//   DB_PATH      path of this competitor's copy of the SQLite database (when "sqlite" is set in api.json)
//   API_NAME     the "name" from api.json
//   COMPETITOR   the competitor's username
//   + everything in "env" from api.json
// CORS headers are added by Traefik, the API does not need to send them.

header('Content-Type: application/json');

function respond(int $status, $data): void
{
    http_response_code($status);
    echo json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

function database(): PDO
{
    $pdo = new PDO('sqlite:' . getenv('DB_PATH'));
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
    return $pdo;
}

$method = $_SERVER['REQUEST_METHOD'];
$path = rtrim(parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH), '/') ?: '/';

if ($method === 'GET' && $path === '/') {
    respond(200, [
        'status' => 'ok',
        'api' => getenv('API_NAME'),
        'competitor' => getenv('COMPETITOR'),
    ]);
}

if ($method === 'GET' && $path === '/items') {
    respond(200, database()->query('SELECT id, name FROM items ORDER BY id')->fetchAll());
}

if ($method === 'POST' && $path === '/items') {
    $body = json_decode(file_get_contents('php://input'), true);
    if (!is_array($body) || !isset($body['name']) || !is_string($body['name']) || $body['name'] === '') {
        respond(422, ['error' => 'A non-empty "name" is required']);
    }
    $db = database();
    $db->prepare('INSERT INTO items (name) VALUES (?)')->execute([$body['name']]);
    respond(201, ['id' => (int) $db->lastInsertId(), 'name' => $body['name']]);
}

respond(404, ['error' => 'Not found']);
