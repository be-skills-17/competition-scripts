#!/usr/bin/env bats
# Dashboard (services/80-dashboard): config.js generated from config/main.json

load test_helper

setup() {
    setup_project
    SERVICES_DIR="$REPO_DIR/services"
    source "$SERVICES_DIR/80-dashboard/service.sh"
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

@test "pre_up runs through run_service_hook" {
    run_service_hook dashboard pre_up
    [ -f "$DYNAMIC_DIR/dashboard/config.js" ]
}

@test "the dashboard is only published on the loopback interface" {
    grep -q '"127.0.0.1:8090:80"' "$SERVICES_DIR/80-dashboard/compose.yaml"
    run grep -c 'traefik' "$SERVICES_DIR/80-dashboard/compose.yaml"
    [ "$output" = "0" ]
}
