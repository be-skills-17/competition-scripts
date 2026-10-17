# shellcheck shell=bash
# Dashboard service helpers: config.js (loaded with service_hooks.sh)

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

