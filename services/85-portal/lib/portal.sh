# shellcheck shell=bash
# Portal service helpers: portal.json (loaded with service_hooks.sh)

# portal.json: the information shown to each competitor once logged in. It holds their passwords: readable by
# root and the www-data group (gid 33, Apache in the php image) only.
write_portal_config() {
    local proto=${GITEA_PROTOCOL:-https} apis dir out
    out=$(service_dynamic_dir portal)
    mkdir -p "$out"

    # Enabled APIs: [{name, host, folder}] with the {subdomain}/{username} placeholders. folder: the API's folder
    # in config/apis/, mounted read-only in the portal for its openapi.json (see compose.yaml)
    apis=$(for dir in $(enabled_apis); do
        jq -c --arg folder "$(basename "$dir")" '{name, host, folder: $folder}' "$dir/api.json"
    done | jq -s '.')

    (umask 027 && jq --arg proto "$proto" --argjson apis "$apis" '
        .domain as $d | .modules as $modules |
        def url($host): "\($proto)://\($host).\($d)/";
        {
            domain: $d,
            links: {gitea: url("git"), phpmyadmin: url("pma"), npm: url("npm")},
            database: {host: $d, port: 3306},
            # Templates offered when creating a module (null: all of them, as import-frameworks does)
            frameworks: (.frameworks.allowed_frameworks // [] | if length == 0 then null else . end),
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
                        url: url(.host | gsub("\\{subdomain\\}"; $c.subdomain) | gsub("\\{username\\}"; $c.username)),
                        folder
                    }]
                })
            }) | from_entries)
        }' "$CONFIG_DIR/main.json" > "$out/portal.json")
    chgrp 33 "$out/portal.json" 2> /dev/null || true
}

