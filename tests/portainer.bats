#!/usr/bin/env bats
# Portainer (services/82-portainer): admin password file read on first start

load test_helper

setup() {
    setup_project
    SERVICES_DIR="$REPO_DIR/services"
    source "$SERVICES_DIR/82-portainer/service_hooks.sh"
}

@test "pre_up writes the admin password, readable by its owner only" {
    PASSWORD='s3cret pass'
    service_portainer_pre_up
    [ "$(cat "$DYNAMIC_DIR/portainer/admin_password")" = 's3cret pass' ]
    [ "$(stat -c %a "$DYNAMIC_DIR/portainer/admin_password")" = "600" ]
}

@test "pre_up can run again and follows a new password" {
    PASSWORD=first
    service_portainer_pre_up
    PASSWORD=second
    service_portainer_pre_up
    [ "$(cat "$DYNAMIC_DIR/portainer/admin_password")" = "second" ]
}
