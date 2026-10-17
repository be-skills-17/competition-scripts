<?php
// Session, CSRF token and redirects

function start_session(): void
{
    session_set_cookie_params([
        'httponly' => true,
        'secure' => ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https',
        'samesite' => 'Lax',
    ]);
    session_start();
}

function csrf_token(): string
{
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(16));
    }
    return $_SESSION['csrf'];
}

// Stops the request when the form does not carry the session's token
function require_csrf(): void
{
    if (!hash_equals(csrf_token(), $_POST['csrf'] ?? '')) {
        http_response_code(400);
        exit('Requête invalide, rechargez la page.');
    }
}

// Redirect after a POST, so reloading the page does not resend the form
function redirect(string $path): never
{
    header('Location: ' . $path, true, 303);
    exit;
}

// Message shown once, on the page displayed after the redirect: ['ok' | 'error', text]
function flash(array $message): void
{
    $_SESSION['flash'] = $message;
}

function take_flash(): ?array
{
    $message = $_SESSION['flash'] ?? null;
    unset($_SESSION['flash']);
    return $message;
}
