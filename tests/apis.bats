#!/usr/bin/env bats
# Native PHP APIs from config/apis/ (src/lib/apis.sh, services/75-apis/service.sh)

load test_helper

setup() {
    setup_project
    SERVICES_DIR="$REPO_DIR/services"
    source "$SERVICES_DIR/75-apis/service.sh"
    mkdir -p "$DATA_DIR"
    DOMAIN=competition.test
    ENTRYPOINT=websecure
    ENABLE_HTTPS=true

    # The versioned template (disabled) and an enabled copy of it
    mkdir -p "$CONFIG_DIR/apis"
    cp -r "$REPO_DIR/config/apis/template" "$CONFIG_DIR/apis/template"
    cp -r "$REPO_DIR/config/apis/template" "$CONFIG_DIR/apis/products"
    edit_api products '.enabled = true | .name = "products" | .host = "{subdomain}-products"'
}

# Apply a jq filter to config/apis/<folder>/api.json
edit_api() {
    local file="$CONFIG_DIR/apis/$1/api.json" tmp
    tmp=$(mktemp)
    jq "$2" "$file" > "$tmp" && mv "$tmp" "$file"
}

@test "the versioned template is disabled" {
    [ "$(jq -r .enabled "$REPO_DIR/config/apis/template/api.json")" = "false" ]
}

@test "only enabled APIs are listed" {
    run enabled_apis
    [ "$output" = "$CONFIG_DIR/apis/products" ]
}

@test "the host name is built from the competitor's subdomain and username" {
    edit_api products '.host = "{username}-{subdomain}-api"'
    run api_host "$CONFIG_DIR/apis/products" comp01 alpha
    [ "$output" = "comp01-alpha-api" ]
}

@test "a valid API passes the configuration check" {
    run validate_configuration
    [ -z "$output" ]
}

@test "disabled APIs are not validated" {
    edit_api products '.enabled = false | .host = "INVALID"'
    run validate_configuration
    [ -z "$output" ]
}

@test "a host without {subdomain} or {username} is rejected" {
    edit_api products '.host = "products"'
    run validate_configuration
    [[ "$output" == *"apis/products/api.json: host: required"* ]]
}

@test "a host colliding with a module is rejected" {
    edit_api products '.host = "{subdomain}-module-a"'
    run validate_configuration
    [[ "$output" == *'host "alpha-module-a" is used more than once'* ]]
}

@test "an API named like a module is rejected" {
    edit_api products '.name = "module-a"'
    run validate_configuration
    [[ "$output" == *'name "module-a" is also a module name'* ]]
}

@test "two enabled APIs with the same name are rejected" {
    cp -r "$CONFIG_DIR/apis/products" "$CONFIG_DIR/apis/products-copy"
    edit_api products-copy '.host = "{subdomain}-other"'
    run validate_configuration
    [[ "$output" == *'name "products" is used by several enabled APIs'* ]]
}

@test "an invalid openapi.json is reported, a missing one is fine" {
    run validate_configuration
    [ -z "$output" ]
    rm "$CONFIG_DIR/apis/products/openapi.json"
    run validate_configuration
    [ -z "$output" ]
    echo '{"openapi": ' > "$CONFIG_DIR/apis/products/openapi.json"
    run validate_configuration
    [[ "$output" == *"apis/products/openapi.json: not a valid JSON object"* ]]
}

@test "missing document_root and sqlite files are reported" {
    edit_api products '.document_root = "web" | .sqlite = "nope.sqlite"'
    run validate_configuration
    [[ "$output" == *'document_root: folder "web" not found'* ]]
    [[ "$output" == *'sqlite: file "nope.sqlite" not found'* ]]
}

@test "paths leaving the API folder are rejected" {
    edit_api products '.document_root = "../other" | .sqlite = "/etc/passwd"'
    run validate_configuration
    [[ "$output" == *"document_root: must be a folder inside the API folder"* ]]
    [[ "$output" == *"sqlite: must be a file inside the API folder"* ]]
}

@test "invalid JSON in api.json is reported" {
    echo '{' > "$CONFIG_DIR/apis/products/api.json"
    run validate_configuration
    [ "$output" = "apis/products/api.json: not valid JSON" ]
}

@test "the compose file has one container per API and competitor" {
    generate_apis_compose "$DYNAMIC_DIR/apis/compose.yaml"
    run cat "$DYNAMIC_DIR/apis/compose.yaml"
    [[ "$output" == *"  comp01_products:"* ]]
    [[ "$output" == *"  comp02_products:"* ]]
    [[ "$output" == *"image: php:8.3-apache"* ]]
    [[ "$output" == *'Host(`alpha-products.competition.test`)'* ]]
    [[ "$output" == *"APACHE_DOCUMENT_ROOT: /var/www/api/public"* ]]
    [[ "$output" == *"$CONFIG_DIR/apis/products:/var/www/api:ro"* ]]
}

@test "env values are passed with \$ escaped for compose" {
    edit_api products '.env = {"PRICE": "10$"}'
    generate_apis_compose "$DYNAMIC_DIR/apis/compose.yaml"
    grep -q 'PRICE: "10\$\$"' "$DYNAMIC_DIR/apis/compose.yaml"
}

@test "no compose file is written when no API is enabled" {
    mkdir -p "$DYNAMIC_DIR/apis"
    echo "services:" > "$DYNAMIC_DIR/apis/compose.yaml"
    edit_api products '.enabled = false'
    generate_apis_compose "$DYNAMIC_DIR/apis/compose.yaml"
    [ ! -f "$DYNAMIC_DIR/apis/compose.yaml" ]
}

@test "each competitor gets a copy of the initial database" {
    prepare_api_data "$CONFIG_DIR/apis/products"
    [ -f "$DATA_DIR/apis/products/comp01/database.sqlite" ]
    [ -f "$DATA_DIR/apis/products/comp02/database.sqlite" ]
}

@test "a redeploy keeps the competitor's data" {
    prepare_api_data "$CONFIG_DIR/apis/products"
    echo modified > "$DATA_DIR/apis/products/comp01/database.sqlite"
    prepare_api_data "$CONFIG_DIR/apis/products"
    [ "$(cat "$DATA_DIR/apis/products/comp01/database.sqlite")" = "modified" ]
}

@test "a reset replaces the data of the given competitor only" {
    prepare_api_data "$CONFIG_DIR/apis/products"
    echo modified > "$DATA_DIR/apis/products/comp01/database.sqlite"
    echo modified > "$DATA_DIR/apis/products/comp02/database.sqlite"
    prepare_api_data "$CONFIG_DIR/apis/products" comp01 true
    cmp -s "$CONFIG_DIR/apis/products/database.sqlite" "$DATA_DIR/apis/products/comp01/database.sqlite"
    [ "$(cat "$DATA_DIR/apis/products/comp02/database.sqlite")" = "modified" ]
}
