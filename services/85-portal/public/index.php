<?php
// Competitor portal: public links, and after logging in with their competition credentials, each competitor's
// own information to copy, and the creation / deletion of their modules' repositories. The code is in ../app
// (outside the document root), the HTML in ../app/templates.

require dirname(__DIR__) . '/app/bootstrap.php';

$portal = load_portal_data();
$error = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    require_csrf();
    $action = $_POST['action'] ?? '';
    if ($action === 'logout') {
        logout();
        redirect('/');
    }
    if (in_array($action, ['create_module', 'delete_module'], true)) {
        $username = current_username($portal);
        if ($username !== null) {
            flash(module_action($portal, $username, $action, $_POST));
        }
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
    'flash' => take_flash(),
]);
