#!/usr/bin/env bats
# config/main.json validation (check-config, and the valid_config filter of init / import-frameworks)

load test_helper

setup() {
    setup_project
}

@test "the fixture config is valid" {
    run validate_configuration
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "the filter prints nothing for a valid config" {
    run filter_valid_config
    [ -z "$output" ]
}

@test "a missing file is reported" {
    rm "$CONFIG_DIR/main.json"
    run validate_configuration
    [[ "$output" == *"main.json not found"* ]]
}

@test "invalid JSON is reported" {
    echo '{"domain": ' > "$CONFIG_DIR/main.json"
    run validate_configuration
    [[ "$output" == "not valid JSON:"* ]]
}

@test "missing required fields are all reported" {
    edit_config 'del(.domain, .username, .modules)'
    run validate_configuration
    [[ "$output" == *"domain: required"* ]]
    [[ "$output" == *"username: required"* ]]
    [[ "$output" == *"modules: required"* ]]
}

@test "the frameworks section is checked by the gitea service (validate hook)" {
    SERVICES_DIR="$REPO_DIR/services"
    source "$SERVICES_DIR/20-gitea/service_hooks.sh"
    edit_config 'del(.frameworks.frameworks_repo) | .frameworks.allowed_frameworks = "laravel"'
    run validate_configuration
    [[ "$output" == *"frameworks.frameworks_repo: required"* ]]
    [[ "$output" == *"frameworks.allowed_frameworks: must be a list"* ]]
}

@test "enable_https must be a boolean, not a string" {
    edit_config '.enable_https = "true"'
    run validate_configuration
    [ "$output" = "enable_https: must be true or false" ]
}

@test "names with uppercase letters or underscores are rejected" {
    edit_config '.modules = ["Module-A", "module_b"] | .competitors[0].subdomain = "Alpha"'
    run validate_configuration
    [[ "$output" == *"modules: required"* ]]
    [[ "$output" == *"competitors[0].subdomain"* ]]
}

@test "passwords with quotes, backslashes or tabs are rejected" {
    edit_config '.password = "a\"b" | .competitors[0].password = "it'"'"'s" | .competitors[1].password = "a\tb"'
    run validate_configuration
    [[ "${lines[0]}" == "password: required"* ]]
    [[ "${lines[1]}" == "competitors[0].password"* ]]
    [[ "${lines[2]}" == "competitors[1].password"* ]]
}

@test "passwords with spaces and symbols are accepted" {
    edit_config '.competitors[0].password = "p@ss w0rd!#"'
    run validate_configuration
    [ -z "$output" ]
}

@test "competitor name is optional but must not be empty when set" {
    edit_config '.competitors[0].name = ""'
    run validate_configuration
    [ "$output" = "competitors[0].name: must be a non-empty string if set" ]
}

@test "duplicate usernames and subdomains are reported" {
    edit_config '.competitors[1].username = "comp01" | .competitors[1].subdomain = "alpha"'
    run validate_configuration
    [[ "$output" == *'username "comp01" is used more than once'* ]]
    [[ "$output" == *'subdomain "alpha" is used more than once'* ]]
}

@test "an empty competitors list is reported" {
    edit_config '.competitors = []'
    run validate_configuration
    [ "$output" = "competitors: required, a non-empty list" ]
}

@test "allowed_frameworks is optional" {
    edit_config 'del(.frameworks.allowed_frameworks)'
    run validate_configuration
    [ -z "$output" ]
}

@test "the filter formats every problem as a list" {
    edit_config '.enable_https = "yes" | .domain = ""'
    run filter_valid_config
    [ "${lines[0]}" = "Invalid configuration:" ]
    [ "${lines[1]}" = "  - domain: required (e.g. \"local.skill17.com\")" ]
    [ "${lines[2]}" = "  - enable_https: must be true or false" ]
}
