#!/usr/bin/env bats
# .env loading and the paths derived from the script location (src/lib/environment.sh)

load test_helper

setup() {
    setup_project
}

@test "paths in an old .env do not override the current location" {
    printf 'DOMAIN="competition.test"\nBASE_DIR="/old/place"\nDATA_DIR="/old/place/data"\n' > "$BASE_DIR/.env"
    load_env_file
    [ "$BASE_DIR" = "$BATS_TEST_TMPDIR/project" ]
    [ "$DATA_DIR" = "$BATS_TEST_TMPDIR/project/data" ]
    [ "$DOMAIN" = "competition.test" ]
}

@test "GITEA_URL is rebuilt when .env does not contain it" {
    printf 'DOMAIN="competition.test"\nGITEA_PROTOCOL="https"\n' > "$BASE_DIR/.env"
    unset GITEA_URL
    load_env_file
    [ "$GITEA_URL" = "https://git.competition.test" ]
}

@test "a missing .env is not an error" {
    rm -f "$BASE_DIR/.env"
    run load_env_file
    [ "$status" -eq 0 ]
}

@test "the saved .env contains no path" {
    DOMAIN=competition.test
    export_environment_variables > /dev/null
    run grep -E '^(BASE|CONFIG|DATA|SERVICES|DYNAMIC_[A-Z]+)_?DIR=' "$BASE_DIR/.env"
    [ "$status" -ne 0 ]
    grep -q '^DOMAIN="competition.test"$' "$BASE_DIR/.env"
}
