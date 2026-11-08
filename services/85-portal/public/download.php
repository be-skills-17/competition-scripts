<?php
// Download of a provided file (config/files, see ../app/lib/files.php), for logged-in competitors:
//   /download.php?file=<name>

require dirname(__DIR__) . '/app/bootstrap.php';

$portal = load_portal_data();
if (current_username($portal) === null) {
    redirect('/');
}

$path = provided_file_path((string) ($_GET['file'] ?? ''));
if ($path === null) {
    http_response_code(404);
    exit('Fichier introuvable.');
}

// A large file takes a while: don't keep the session locked, the competitor can use the portal meanwhile
session_write_close();

$name = basename($path);
header('Content-Type: application/octet-stream');
header('Content-Length: ' . filesize($path));
header('Content-Disposition: attachment; filename="' . addcslashes($name, '"\\') . '"; filename*=UTF-8\'\'' . rawurlencode($name));
header('X-Content-Type-Options: nosniff');
header('Cache-Control: no-store');
readfile($path);
