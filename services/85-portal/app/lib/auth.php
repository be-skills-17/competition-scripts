<?php
// Competitors log in with their competition username and password (config/main.json)

function login(array $portal, string $username, string $password): bool
{
    $competitor = $portal['competitors'][$username] ?? null;
    if ($competitor !== null && hash_equals($competitor['password'], $password)) {
        session_regenerate_id(true);
        $_SESSION['user'] = $username;
        return true;
    }
    usleep(800000); // slows down password guessing
    return false;
}

function logout(): void
{
    $_SESSION = [];
    session_destroy();
}

// Username of the logged-in competitor, null when nobody is logged in (or the competitor was removed)
function current_username(array $portal): ?string
{
    $username = $_SESSION['user'] ?? null;
    return isset($portal['competitors'][$username]) ? $username : null;
}
