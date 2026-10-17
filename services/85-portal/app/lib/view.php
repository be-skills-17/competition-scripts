<?php
// Rendering helpers: escaping, templates, icons and copy buttons

function e($value): string
{
    return htmlspecialchars((string) $value, ENT_QUOTES, 'UTF-8');
}

// Render app/templates/<name>.php with the given variables
function render(string $name, array $variables = []): void
{
    extract($variables);
    require __DIR__ . '/../templates/' . $name . '.php';
}

const ICONS = [
    'copy' => '<rect x="9" y="9" width="12" height="12" rx="2"/><path d="M5 15H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v1"/>',
    'eye' => '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    'open' => '<path d="M14 4h6v6"/><path d="M10 14 20 4"/><path d="M19 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1h5"/>',
    'logout' => '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="m16 17 5-5-5-5"/><path d="M21 12H9"/>',
];

function icon(string $name): string
{
    return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"'
        . ' stroke-linejoin="round" aria-hidden="true">' . ICONS[$name] . '</svg>';
}

// Icon button with a tooltip (data-tip, see assets/portal.js); $attributes are added as is
function icon_button(string $class, string $tip, string $icon, string $attributes = ''): string
{
    return '<button type="button" class="icon-btn ' . $class . '" data-tip="' . e($tip) . '" aria-label="' . e($tip)
        . '"' . $attributes . '>' . icon($icon) . '</button>';
}

// A value with a copy button
function copyable($value): string
{
    return copyable_as((string) $value, (string) $value);
}

// A value shown one way and copied another (e.g. a URL whose password is hidden on screen)
function copyable_as(string $shown, string $copied, bool $disabled = false): string
{
    $attributes = ' data-copy="' . e($copied) . '"' . ($disabled ? ' aria-disabled="true"' : '');
    return '<span class="cp"><code>' . e($shown) . '</code>'
        . icon_button('copy', $disabled ? "Créez d'abord le dépôt" : 'Copier', 'copy', $attributes) . '</span>';
}

// A secret hidden until "Afficher", with a copy button
function copyable_secret(string $value): string
{
    return '<span class="cp"><span class="secret" data-value="' . e($value) . '">' . HIDDEN . '</span>'
        . icon_button('reveal', 'Afficher', 'eye')
        . icon_button('copy', 'Copier', 'copy', ' data-copy="' . e($value) . '"') . '</span>';
}

// Section title: a count (or symbol) in the yellow tab, the label in the navy band
function band($count, string $label): string
{
    return '<div class="band"><span class="n">' . e($count) . '</span><span class="l">' . e($label) . '</span></div>';
}

// Status of a module's repository: created / missing / unknown (Gitea unreachable)
function repository_state(string $state): string
{
    [$class, $label] = [
        'created' => ['ok', '✓ créé'],
        'missing' => ['missing', '✗ pas encore créé'],
        'unknown' => ['unknown', '? Gitea injoignable'],
    ][$state];
    return '<span class="status ' . $class . '">' . $label . '</span>';
}
