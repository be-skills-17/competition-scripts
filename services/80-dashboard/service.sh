# shellcheck shell=bash
# Dashboard: static page served by nginx on 127.0.0.1:8090 (see compose.yaml)

# config.js gives the page the domain, the competitors and the modules of config/main.json, and the enabled APIs
# (api-docs.html shows the openapi.json of their folder, see nginx.conf)
write_dashboard_config() {
    local dir apis api_dir
    dir=$(service_dynamic_dir dashboard)
    mkdir -p "$dir"
    apis=$(for api_dir in $(enabled_apis); do
        jq -c --arg folder "$(basename "$api_dir")" '{name, folder: $folder}' "$api_dir/api.json"
    done | jq -s '.')
    jq --argjson apis "$apis" '{
            domain: .domain,
            modules: .modules,
            competitors: [.competitors[] | {name: (.name // .username), username, subdomain}],
            apis: $apis
        }' "$CONFIG_DIR/main.json" \
        | sed '1s/^/window.DASHBOARD_CONFIG = /; $s/$/;/' > "$dir/config.js"
}

# Before every "up" (init, restore, recreate): the file must exist, or Docker would mount an empty directory
service_dashboard_pre_up() {
    write_dashboard_config
}
