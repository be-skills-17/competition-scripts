#!/usr/bin/env bats
# WUD (services/60-wud): Gitea registry token in dynamic/wud/registry.env

load test_helper

setup() {
    setup_project
    SERVICES_DIR="$REPO_DIR/services"
    source "$SERVICES_DIR/60-wud/service_hooks.sh"
    USERNAME=root
    PASSWORD=adminpw
    GITEA_URL=https://git.competition.test
    # Gitea: the registry accepts the logins listed in $VALID ("down": no answer at all); create_pat gives
    # "newtoken" (it runs in a subshell: it can't change $VALID)
    VALID="adminpw newtoken"
    curl() {
        [ "$VALID" = down ] && { echo 000; return 7; }
        local arg secret
        for arg in "$@"; do [[ "$arg" == root:* ]] && secret=${arg#root:}; done
        [[ " $VALID " == *" $secret "* ]] && echo 200 || echo 401
    }
    create_pat() {
        [ "$VALID" = down ] && { echo "Failed to create token. Response: "; return 1; }
        echo "created $2" >> "$BATS_TEST_TMPDIR/created"
        echo newtoken
    }
}

registry_secret() {
    sed -n 's/^WUD_REGISTRY_CUSTOM_GITEA_PASSWORD=//p' "$DYNAMIC_DIR/wud/registry.env"
}

@test "a read:package token is created and only root can read it" {
    write_wud_registry_env
    [ "$(registry_secret)" = newtoken ]
    [ "$(cat "$BATS_TEST_TMPDIR/created")" = 'created ["read:package"]' ]
    [ "$(stat -c %a "$DYNAMIC_DIR/wud/registry.env")" = "600" ]
}

@test "a token still accepted by Gitea is kept" {
    mkdir -p "$DYNAMIC_DIR/wud"
    echo "WUD_REGISTRY_CUSTOM_GITEA_PASSWORD=oldtoken" > "$DYNAMIC_DIR/wud/registry.env"
    VALID="adminpw newtoken oldtoken"
    write_wud_registry_env
    [ "$(registry_secret)" = oldtoken ]
    [ ! -f "$BATS_TEST_TMPDIR/created" ]
}

@test "a token refused by Gitea (or the password fallback) is replaced" {
    mkdir -p "$DYNAMIC_DIR/wud"
    for old in revoked adminpw; do
        echo "WUD_REGISTRY_CUSTOM_GITEA_PASSWORD=$old" > "$DYNAMIC_DIR/wud/registry.env"
        write_wud_registry_env
        [ "$(registry_secret)" = newtoken ]
    done
}

@test "Gitea down: an existing token is kept (under the current name), otherwise the admin password is used" {
    VALID=down
    write_wud_registry_env
    [ "$(registry_secret)" = adminpw ]
    for name in CUSTOM_GITEA GITEA_PRIVATE; do
        echo "WUD_REGISTRY_${name}_PASSWORD=oldtoken" > "$DYNAMIC_DIR/wud/registry.env"
        write_wud_registry_env
        [ "$(registry_secret)" = oldtoken ]
    done
}

@test "the token written before the custom registry is reused under the new variable name" {
    mkdir -p "$DYNAMIC_DIR/wud"
    echo "WUD_REGISTRY_GITEA_PRIVATE_PASSWORD=oldtoken" > "$DYNAMIC_DIR/wud/registry.env"
    VALID="adminpw newtoken oldtoken"
    write_wud_registry_env
    [ "$(registry_secret)" = oldtoken ]
    [ ! -f "$BATS_TEST_TMPDIR/created" ]
}

@test "compose declares Gitea as a custom registry (cached tokens), password from the optional env_file" {
    run grep -c 'PASSWORD=' "$SERVICES_DIR/60-wud/compose.yaml"
    [ "$output" = "1" ]  # WUD_AUTH_ADMIN_PASSWORD only (WUD's own login)
    grep -q 'WUD_REGISTRY_CUSTOM_GITEA_URL=${GITEA_URL}' "$SERVICES_DIR/60-wud/compose.yaml"
    run grep -c 'WUD_REGISTRY_GITEA_' "$SERVICES_DIR/60-wud/compose.yaml"
    [ "$output" = "0" ]
    grep -q 'path: "${DYNAMIC_DIR}/wud/registry.env"' "$SERVICES_DIR/60-wud/compose.yaml"
    grep -q 'required: false' "$SERVICES_DIR/60-wud/compose.yaml"
}
