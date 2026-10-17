#!/usr/bin/env bats
# Dashboard (services/80-dashboard): config.js generated from config/main.json

load test_helper

setup() {
    setup_project
    SERVICES_DIR="$REPO_DIR/services"
    source "$SERVICES_DIR/80-dashboard/service_hooks.sh"
}

# The JSON object assigned to window.DASHBOARD_CONFIG
config_json() {
    sed '1s/^window.DASHBOARD_CONFIG = //; $s/;$//' "$DYNAMIC_DIR/dashboard/config.js"
}

@test "config.js assigns window.DASHBOARD_CONFIG" {
    service_dashboard_pre_up
    [[ "$(head -n1 "$DYNAMIC_DIR/dashboard/config.js")" == "window.DASHBOARD_CONFIG = {" ]]
    [[ "$(tail -n1 "$DYNAMIC_DIR/dashboard/config.js")" == "};" ]]
}

@test "config.js contains the domain, modules and competitors, without passwords" {
    service_dashboard_pre_up
    run config_json
    [ "$(jq -r .domain <<< "$output")" = "competition.test" ]
    [ "$(jq -c .modules <<< "$output")" = '["module-a","module-b"]' ]
    [ "$(jq -c '.competitors[0]' <<< "$output")" = '{"name":"Alice","username":"comp01","subdomain":"alpha"}' ]
    [[ "$output" != *pass* ]]
}

@test "a competitor without name is shown with its username" {
    service_dashboard_pre_up
    run config_json
    [ "$(jq -r '.competitors[1].name' <<< "$output")" = "comp02" ]
}

@test "config.js lists the enabled APIs with their folder (API documentation)" {
    mkdir -p "$CONFIG_DIR/apis"
    cp -r "$REPO_DIR/config/apis/template" "$CONFIG_DIR/apis/products"
    jq '.enabled = true | .name = "products-api"' "$REPO_DIR/config/apis/template/api.json" \
        > "$CONFIG_DIR/apis/products/api.json"
    write_dashboard_config
    [ "$(config_json | jq -c .apis)" = '[{"name":"products-api","folder":"products"}]' ]
}

@test "nginx serves only the openapi.json of the API folders" {
    grep -q '"${CONFIG_DIR}/apis:/etc/nginx/apis:ro"' "$SERVICES_DIR/80-dashboard/compose.yaml"
    run grep -c '/etc/nginx/apis' "$SERVICES_DIR/80-dashboard/nginx.conf"
    [ "$output" = "1" ]
    grep -q 'alias /etc/nginx/apis/$1/openapi.json;' "$SERVICES_DIR/80-dashboard/nginx.conf"
}

@test "pre_up runs through run_service_hook" {
    run_service_hook dashboard pre_up
    [ -f "$DYNAMIC_DIR/dashboard/config.js" ]
}

@test "the dashboard is only published on the loopback interface" {
    grep -q '"127.0.0.1:8090:80"' "$SERVICES_DIR/80-dashboard/compose.yaml"
    run grep -c 'traefik' "$SERVICES_DIR/80-dashboard/compose.yaml"
    [ "$output" = "0" ]
}

@test "Glances enables every plugin the dashboard reads (the others are disabled)" {
    local enabled read
    enabled=$(grep -o -- '--enable-plugin [a-z,]*' "$SERVICES_DIR/65-glances/compose.yaml" | cut -d' ' -f2)
    grep -q -- '--disable-plugin all' "$SERVICES_DIR/65-glances/compose.yaml"
    # const GLANCES_PLUGINS = ['cpu', 'mem', ...];
    read=$(grep -o "const GLANCES_PLUGINS = \[[^]]*\]" "$SERVICES_DIR/80-dashboard/html/index.html" \
        | grep -o "'[a-z]*'" | tr -d "'" | paste -sd, -)
    [ -n "$read" ]
    [ "$read" = "$enabled" ] || { echo "dashboard reads $read, Glances enables $enabled"; return 1; }
}

@test "the dashboard asks Glances once per refresh (/all), not once per plugin" {
    grep -q "getJSON('/all')" "$SERVICES_DIR/80-dashboard/html/index.html"
    run grep -c "map(getJSON)" "$SERVICES_DIR/80-dashboard/html/index.html"
    [ "$output" = "0" ]
}
