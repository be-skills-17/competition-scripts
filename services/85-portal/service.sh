# shellcheck shell=bash
# Portal: competitor dashboard on the main domain (see compose.yaml and public/index.php)

# portal.json: the information shown to each competitor once logged in. It holds their passwords: readable by
# root and the www-data group (gid 33, Apache in the php image) only.
write_portal_config() {
    local proto=${GITEA_PROTOCOL:-https} apis dir
    mkdir -p "$DYNAMIC_PORTAL_DIR"

    # Enabled APIs: [{name, host}] with the {subdomain}/{username} placeholders
    apis=$(for dir in $(enabled_apis); do jq -c '{name, host}' "$dir/api.json"; done | jq -s '.')

    (umask 027 && jq --arg proto "$proto" --argjson apis "$apis" '
        .domain as $d | .modules as $modules |
        def url($host): "\($proto)://\($host).\($d)/";
        {
            domain: $d,
            links: {gitea: url("git"), phpmyadmin: url("pma"), npm: url("npm")},
            database: {host: $d, port: 3306},
            competitors: (.competitors | map({
                key: .username,
                value: (. as $c | {
                    name: (.name // .username),
                    password,
                    subdomain,
                    modules: [$modules[] | {
                        name: .,
                        url: url("\($c.subdomain)-\(.)"),
                        database: "\($c.username)_\(.)",
                        repository: "\($proto)://git.\($d)/\($c.username)/\(.).git",
                        image: "git.\($d)/\($c.username)/\(.)"
                    }],
                    apis: [$apis[] | {
                        name,
                        url: url(.host | gsub("\\{subdomain\\}"; $c.subdomain) | gsub("\\{username\\}"; $c.username))
                    }]
                })
            }) | from_entries)
        }' "$CONFIG_DIR/main.json" > "$DYNAMIC_PORTAL_DIR/portal.json")
    chgrp 33 "$DYNAMIC_PORTAL_DIR/portal.json" 2> /dev/null || true
}

# Before every "up" (init, restore, recreate): the file must exist, and APIs may have changed
service_portal_pre_up() {
    write_portal_config
}
