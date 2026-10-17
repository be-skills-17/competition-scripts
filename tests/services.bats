#!/usr/bin/env bats
# Service discovery in services/<NN>-<name>/ and hooks (src/lib/services.sh)

load test_helper

setup() {
    setup_project
    add_service 10-proxy
    add_service 30-db
    add_service 20-git --hooks <<'HOOKS'
service_git_post_init() { echo "post_init git $*"; }
HOOKS
    add_service 40-generated --hooks <<'HOOKS'
service_generated_compose_file() { echo "$DYNAMIC_DIR/generated.yaml"; }
HOOKS
}

@test "services are listed in NN order, without the number" {
    run service_names
    [ "$output" = $'proxy\ngit\ndb\ngenerated' ]
}

@test "reversed order goes from the last service to the first" {
    run service_names_reversed
    [ "$output" = $'generated\ndb\ngit\nproxy' ]
}

@test "directories without a NN- prefix are ignored" {
    mkdir -p "$SERVICES_DIR/notes"
    run service_names
    [[ "$output" != *notes* ]]
}

@test "service_dir finds the directory from the name" {
    run service_dir git
    [ "$output" = "$SERVICES_DIR/20-git" ]
}

@test "service_dir fails for an unknown service" {
    run service_dir nope
    [ "$status" -ne 0 ]
}

@test "the compose file defaults to the service's compose.yaml" {
    run service_compose_file proxy
    [ "$output" = "$SERVICES_DIR/10-proxy/compose.yaml" ]
}

@test "the compose_file hook overrides the compose file" {
    run service_compose_file generated
    [ "$output" = "$DYNAMIC_DIR/generated.yaml" ]
}

@test "compose_files lists every compose file in start order" {
    run compose_files
    [ "${lines[0]}" = "$SERVICES_DIR/10-proxy/compose.yaml" ]
    [ "${lines[3]}" = "$DYNAMIC_DIR/generated.yaml" ]
}

@test "a defined hook is called with its arguments" {
    run run_service_hook git post_init a b
    [ "$output" = "post_init git a b" ]
}

@test "a missing hook is silently skipped" {
    run run_service_hook proxy post_init
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "dashes in the service name become underscores in the hook name" {
    add_service 50-my-svc --hooks <<'HOOKS'
service_my_svc_clean() { echo cleaned; }
HOOKS
    run run_service_hook my-svc clean
    [ "$output" = "cleaned" ]
}

@test "the real services directory defines the expected order" {
    SERVICES_DIR="$REPO_DIR/services"
    run service_names
    [ "$output" = $'traefik\ngitea\nrunners\nmysql\nverdaccio\nwud\nglances\ncompetitors\napis\ndashboard\nportal' ]
}

@test "generated files go to dynamic/<service>/" {
    run service_dynamic_dir portal
    [ "$output" = "$DYNAMIC_DIR/portal" ]
}

@test "the core does not reference any service's generated files" {
    run grep -rnE 'dynamic/(docker|frameworks|dashboard|portal|competitors|apis)|DYNAMIC_[A-Z]+_DIR' "$REPO_DIR/src"
    [ "$status" -ne 0 ]
}

@test "deploy-apis does not call other services directly (they refresh through their pre_up hook)" {
    run grep -nE 'portal|dashboard' "$REPO_DIR/src/deploy_apis_command.sh"
    [[ "$output" != *write_* ]]
    grep -q 'run_service_hook "$name" pre_up' "$REPO_DIR/src/deploy_apis_command.sh"
}
