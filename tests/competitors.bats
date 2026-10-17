#!/usr/bin/env bats
# Files generated from config/main.json: competitors compose file and MySQL databases

load test_helper

setup() {
    setup_project
    SERVICES_DIR="$REPO_DIR/services"
    source "$SERVICES_DIR/70-competitors/service_hooks.sh"
    DOMAIN=competition.test
    ENTRYPOINT=websecure
    ENABLE_HTTPS=true
    MODULES="module-a module-b"
}

@test "mysql pre_init creates one database and grant per competitor and module" {
    source "$REPO_DIR/services/40-mysql/service_hooks.sh"
    service_mysql_pre_init > /dev/null
    run cat "$CONFIG_DIR/mysql/competitors.sql"
    [ "$(grep -c 'CREATE DATABASE' <<< "$output")" -eq 4 ]
    [[ "$output" == *'CREATE DATABASE IF NOT EXISTS `comp01_module-a`'* ]]
    [[ "$output" == *"CREATE USER IF NOT EXISTS 'comp02'@'%' IDENTIFIED BY 'pass 02'"* ]]
    [[ "$output" == *'GRANT ALL PRIVILEGES ON `comp02_module-b`.* TO '"'comp02'@'%'"* ]]
}

@test "mysql pre_init replaces the previous competitors.sql" {
    source "$REPO_DIR/services/40-mysql/service_hooks.sh"
    echo "OLD CONTENT" > "$CONFIG_DIR/mysql/competitors.sql"
    service_mysql_pre_init > /dev/null
    run grep -c "OLD CONTENT" "$CONFIG_DIR/mysql/competitors.sql"
    [ "$output" = "0" ]
}

@test "every competitor is processed, the username is shown when name is missing" {
    create_competitor_user() { echo "user $1 $2"; }
    add_competitor_to_team() { :; }
    create_user_secrets() { :; }
    process_competitor_module() { echo "module $1 $2 $3"; }

    run process_all_competitors "$CONFIG_FILE"
    [[ "$output" == *"Competitor: Alice (subdomain: alpha)"* ]]
    [[ "$output" == *"Competitor: comp02 (subdomain: beta)"* ]]
    [[ "$output" == *"user comp02 pass 02"* ]]
    [[ "$output" == *"module comp01 module-b alpha"* ]]
    [ "$(grep -c '^module ' <<< "$output")" -eq 4 ]
}

@test "the competitors compose file has one service per module with its route" {
    push_initial_module_image() { :; }
    initialize_competitors_config > /dev/null
    process_competitor_module comp01 module-a alpha
    finalize_docker_compose_config

    run cat "$DYNAMIC_DIR/competitors/compose.yaml"
    [[ "${lines[0]}" == "services:" ]]
    [[ "$output" == *"  comp01_module-a:"* ]]
    [[ "$output" == *"image: git.competition.test/comp01/module-a:1.0.0"* ]]
    [[ "$output" == *'rule=Host(`alpha-module-a.competition.test`)'* ]]
    [[ "$output" == *"external: true"* ]]
}

@test "WUD watches the x.y.z tags of each module, not their digest" {
    push_initial_module_image() { :; }
    initialize_competitors_config > /dev/null
    process_competitor_module comp01 module-a alpha

    run cat "$DYNAMIC_DIR/competitors/compose.yaml"
    [[ "$output" == *'"wud.watch=true"'* ]]
    [[ "$output" == *"wud.tag.include=^\\d+\\.\\d+\\.\\d+\$\$"* ]]
    [[ "$output" != *"wud.watch.digest"* ]]
    [[ "$output" != *"wud.registry"* ]]
}

@test "each module gets its database and URL as environment variables, on the competitors-db network" {
    push_initial_module_image() { :; }
    initialize_competitors_config > /dev/null
    process_competitor_module comp01 module-a alpha 'pa$s word'
    finalize_docker_compose_config

    run cat "$DYNAMIC_DIR/competitors/compose.yaml"
    [[ "$output" == *"      - competitors-db"* ]]
    [[ "$output" == *"DB_HOST: competitor_db"* ]]
    [[ "$output" == *'DB_DATABASE: "comp01_module-a"'* ]]
    [[ "$output" == *'DB_USERNAME: "comp01"'* ]]
    [[ "$output" == *'DB_PASSWORD: "pa$$s word"'* ]]
    [[ "$output" == *'APP_URL: "https://alpha-module-a.competition.test"'* ]]
    [[ "$output" == *$'  competitors-db:\n    external: true'* ]]
}

@test "APP_URL uses http when HTTPS is disabled" {
    push_initial_module_image() { :; }
    ENABLE_HTTPS=false
    initialize_competitors_config > /dev/null
    process_competitor_module comp01 module-a alpha pass01

    run cat "$DYNAMIC_DIR/competitors/compose.yaml"
    [[ "$output" == *'APP_URL: "http://alpha-module-a.competition.test"'* ]]
}
