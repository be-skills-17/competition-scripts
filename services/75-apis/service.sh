# shellcheck shell=bash
# APIs: native PHP APIs from config/apis/, one container per API and competitor (see src/lib/apis.sh)

# The compose file is generated from the enabled APIs by pre_init (and deploy-apis)
service_apis_compose_file() {
    echo "$(service_dynamic_dir apis)/compose.yaml"
}

# SQLite copies and compose file; no compose file at all when no API is enabled
service_apis_pre_init() {
    local dir
    for dir in $(enabled_apis); do
        log_info "API $(api_field "$dir" .name) ($(basename "$dir"))"
        prepare_api_data "$dir"
    done
    generate_apis_compose "$(service_apis_compose_file)"
}

# Containers of APIs disabled since the last deploy are not in the compose file anymore
service_apis_clean() {
    docker ps -aq --filter label=competition.api | xargs -r docker rm -f > /dev/null
}

# Print one line per problem in the api.json files (validate hook: check-config, init, deploy-apis...)
service_apis_validate() {
    # Host names already used by the other services
    local reserved_hosts=(git npm wud pma db)
    local file label
    for file in "$CONFIG_DIR"/apis/*/api.json; do
        [ -f "$file" ] || continue
        label="apis/$(basename "$(dirname "$file")")/api.json"
        if ! jq empty "$file" 2> /dev/null; then
            echo "$label: not valid JSON"
            continue
        fi
        jq -r --arg label "$label" '
            def text: type == "string" and length > 0;
            def check(cond; message): if cond then empty else "\($label): \(message)" end;
            check(.enabled | type == "boolean"; "enabled: must be true or false"),
            if .enabled != true then empty else
                check(.name | text and test("^[a-z0-9][a-z0-9-]*$");
                    "name: required, lowercase letters, digits and dashes only"),
                check(.host | text and test("^[a-z0-9{}-]+$") and test("\\{(subdomain|username)\\}")
                        and (gsub("\\{(subdomain|username)\\}"; "") | test("^[a-z0-9-]*$"));
                    "host: required, lowercase letters, digits, dashes and {subdomain} or {username} (e.g. \"{subdomain}-api\")"),
                check(.document_root | . == null or (text and (test("(^/|\\.\\.)") | not));
                    "document_root: must be a folder inside the API folder"),
                check(.php_version | . == null or (type == "string" and test("^[0-9]+\\.[0-9]+$"));
                    "php_version: must look like \"8.3\""),
                check(.sqlite | . == null or (text and (test("(^/|\\.\\.)") | not));
                    "sqlite: must be a file inside the API folder"),
                check(.env | . == null or (type == "object" and all(.[]; type == "string")
                        and all(keys[]; test("^[A-Za-z_][A-Za-z0-9_]*$")));
                    "env: must be an object of string values with valid variable names")
            end
        ' "$file"

        # Files referenced by an enabled API must exist
        if [ "$(jq -r '.enabled' "$file")" = "true" ]; then
            local dir document_root sqlite
            dir=$(dirname "$file")
            document_root=$(jq -r '.document_root // "."' "$file")
            sqlite=$(jq -r '.sqlite // empty' "$file")
            [ -d "$dir/$document_root" ] || echo "$label: document_root: folder \"$document_root\" not found"
            [ -z "$sqlite" ] || [ -f "$dir/$sqlite" ] || echo "$label: sqlite: file \"$sqlite\" not found"
        fi
    done

    # Names and host names must not collide between APIs, modules and the other services
    local apis_json
    apis_json=$(for file in "$CONFIG_DIR"/apis/*/api.json; do
        [ -f "$file" ] && jq -c 'select(.enabled == true and (.name | type) == "string" and (.host | type) == "string")
            | {name, host}' "$file" 2> /dev/null
    done | jq -s '.')
    jq -r --argjson apis "$apis_json" --argjson reserved "$(printf '%s\n' "${reserved_hosts[@]}" | jq -R . | jq -s .)" '
        def duplicates: group_by(.) | map(select(length > 1) | .[0]) | .[];
        .modules as $modules
        | ($apis | map(.name) | duplicates | "apis: name \"\(.)\" is used by several enabled APIs"),
          ($apis[] | .name as $n | select($modules | index($n)) | "apis: name \"\($n)\" is also a module name"),
          ([(.competitors[] as $c
             | ($modules[] | "\($c.subdomain)-\(.)"),
               ($apis[] | .host | gsub("\\{subdomain\\}"; $c.subdomain) | gsub("\\{username\\}"; $c.username))),
            $reserved[]
           ] | duplicates | "apis: host \"\(.)\" is used more than once (modules, APIs or other services)")
    ' "$CONFIG_DIR/main.json"
}
