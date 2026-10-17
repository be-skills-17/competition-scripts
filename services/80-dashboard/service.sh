# shellcheck shell=bash
# Dashboard: static page served by nginx on 127.0.0.1:8090 (see compose.yaml)

# config.js gives the page the domain, the competitors and the modules of config/main.json
write_dashboard_config() {
    local dir
    dir=$(service_dynamic_dir dashboard)
    mkdir -p "$dir"
    jq '{
            domain: .domain,
            modules: .modules,
            competitors: [.competitors[] | {name: (.name // .username), username, subdomain}]
        }' "$CONFIG_DIR/main.json" \
        | sed '1s/^/window.DASHBOARD_CONFIG = /; $s/$/;/' > "$dir/config.js"
}

# Before every "up" (init, restore, recreate): the file must exist, or Docker would mount an empty directory
service_dashboard_pre_up() {
    write_dashboard_config
}
