#!/usr/bin/env bats
# Verdaccio config generation: npm proxy on/off (services/50-verdaccio/service.sh)

load test_helper

setup() {
    setup_project
    source "$REPO_DIR/services/50-verdaccio/service.sh"
    mkdir -p "$CONFIG_DIR/verdaccio"
    cp "$REPO_DIR/config/verdaccio/config.template.yaml" "$CONFIG_DIR/verdaccio/"
    CONFIG="$CONFIG_DIR/verdaccio/config.yaml"
}

@test "on: the template is used as is, with a generated header" {
    write_verdaccio_config on
    [ "$(head -n1 "$CONFIG")" = "# Generated from config.template.yaml by competition.sh (npm proxy: on), do not edit" ]
    diff <(tail -n +2 "$CONFIG") "$CONFIG_DIR/verdaccio/config.template.yaml"
}

@test "off: no uplink, no proxy, no audit middleware" {
    write_verdaccio_config off
    run grep -nE '^uplinks:|^middlewares:|^[[:space:]]*proxy:|registry\.npmjs\.org' "$CONFIG"
    [ "$status" -ne 0 ]
}

@test "off: storage, packages and listen are kept" {
    write_verdaccio_config off
    grep -q '^storage: /verdaccio/storage' "$CONFIG"
    grep -q "^  '\*\*':" "$CONFIG"
    grep -q "^  '@\*/\*':" "$CONFIG"
    grep -q '^listen: 0.0.0.0:4873' "$CONFIG"
}

@test "the mode is read back from the generated config" {
    write_verdaccio_config off
    [ "$(verdaccio_proxy_mode)" = off ]
    write_verdaccio_config on
    [ "$(verdaccio_proxy_mode)" = on ]
}

@test "main.json has no npm section anymore: it is ignored, not validated" {
    edit_config '.npm = "anything"'
    run validate_configuration
    [ -z "$output" ]
}

@test "the cached platforms include glibc, musl and Windows" {
    [[ " ${VERDACCIO_PLATFORMS[*]} " == *" linux-x64 "* ]]
    [[ " ${VERDACCIO_PLATFORMS[*]} " == *" linux-x64-musl "* ]]
    [[ " ${VERDACCIO_PLATFORMS[*]} " == *" win32-x64 "* ]]
}
