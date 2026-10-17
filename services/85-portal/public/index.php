<?php
// Competitor portal: public links, and after logging in with their competition credentials, each competitor's
// own information to copy. The code is in ../app (outside the document root), the HTML in ../app/templates.

require dirname(__DIR__) . '/app/bootstrap.php';

$portal = load_portal_data();
$error = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    require_csrf();
    if (($_POST['action'] ?? '') === 'logout') {
        logout();
        redirect('/');
    }
    if (login($portal, trim($_POST['username'] ?? ''), $_POST['password'] ?? '')) {
        redirect('/');
    }
    $error = 'Identifiant ou mot de passe incorrect.';
}

$username = current_username($portal);
render('layout', [
    'portal' => $portal,
    'me' => $username === null ? null : competitor_view($portal, $username),
    'error' => $error,
]);
