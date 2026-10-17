#!/usr/bin/env bats
# Competitor portal (services/85-portal): portal.json generated from config/main.json and config/apis

load test_helper

setup() {
    setup_project
    SERVICES_DIR="$REPO_DIR/services"
    source "$SERVICES_DIR/85-portal/service.sh"
    GITEA_PROTOCOL=https
}

portal() {
    jq -r "$1" "$DYNAMIC_PORTAL_DIR/portal.json"
}

@test "public links and database use the domain" {
    write_portal_config
    [ "$(portal .links.gitea)" = "https://git.competition.test/" ]
    [ "$(portal .links.npm)" = "https://npm.competition.test/" ]
    [ "$(portal .database.host)" = "competition.test" ]
}

@test "each competitor gets their password, modules, databases and repositories" {
    write_portal_config
    [ "$(portal .competitors.comp02.password)" = "pass 02" ]
    [ "$(portal '.competitors.comp01.modules[1].url')" = "https://alpha-module-b.competition.test/" ]
    [ "$(portal '.competitors.comp01.modules[1].database')" = "comp01_module-b" ]
    [ "$(portal '.competitors.comp02.modules[0].repository')" = "https://git.competition.test/comp02/module-a.git" ]
}

@test "the name falls back to the username" {
    write_portal_config
    [ "$(portal .competitors.comp01.name)" = "Alice" ]
    [ "$(portal .competitors.comp02.name)" = "comp02" ]
}

@test "the admin credentials are not in portal.json" {
    write_portal_config
    run grep -c 'admin password' "$DYNAMIC_PORTAL_DIR/portal.json"
    [ "$output" = "0" ]
}

@test "portal.json is not readable by other users" {
    write_portal_config
    [ "$(stat -c %a "$DYNAMIC_PORTAL_DIR/portal.json")" = "640" ]
}

@test "enabled APIs get each competitor's URL" {
    mkdir -p "$CONFIG_DIR/apis"
    cp -r "$REPO_DIR/config/apis/template" "$CONFIG_DIR/apis/products"
    jq '.enabled = true | .name = "products" | .host = "{username}-{subdomain}-products"' \
        "$REPO_DIR/config/apis/template/api.json" > "$CONFIG_DIR/apis/products/api.json"
    write_portal_config
    [ "$(portal '.competitors.comp02.apis[0].url')" = "https://comp02-beta-products.competition.test/" ]
}

@test "no API section when no API is enabled" {
    write_portal_config
    [ "$(portal '.competitors.comp01.apis | length')" = "0" ]
}

@test "the portal is routed on the bare domain and the Traefik dashboard is not public" {
    grep -q 'traefik.http.routers.portal.rule: Host(`${DOMAIN}`)' "$SERVICES_DIR/85-portal/compose.yaml"
    run grep -c 'traefik.http.routers' "$SERVICES_DIR/10-traefik/compose.yaml"
    [ "$output" = "0" ]
    grep -q '"127.0.0.1:8091:8080"' "$SERVICES_DIR/10-traefik/compose.yaml"
}

@test "the portal asks Gitea on the internal network for the repositories" {
    grep -q 'GITEA_API_URL: http://gitea:3000/api/v1' "$SERVICES_DIR/85-portal/compose.yaml"
    grep -q "getenv('GITEA_API_URL')" "$SERVICES_DIR/85-portal/public/index.php"
}

