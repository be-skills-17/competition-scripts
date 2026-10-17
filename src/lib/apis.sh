# Native PHP APIs provided by the organizers, one container per API and competitor.
# Each API is a folder config/apis/<folder>/ (not versioned, except the template) with an api.json:
#   enabled        true/false, disabled APIs are ignored everywhere
#   name           used in container names (<username>_<name>) and data/apis/<name>/
#   host           host name without the domain, with {subdomain} and/or {username}, e.g. "{subdomain}-api"
#   document_root  folder served by Apache, relative to the API folder (default ".")
#   php_version    image php:<version>-apache (default "8.3")
#   sqlite         initial SQLite database, relative to the API folder, copied once per competitor (optional)
#   env            extra environment variables (optional)

APIS_DEFAULT_PHP_VERSION="8.3"
# Host names already used by the other services
APIS_RESERVED_HOSTS=(git npm wud pma db)

# Folders of the enabled APIs, one per line
enabled_apis() {
    local file
    for file in "$CONFIG_DIR"/apis/*/api.json; do
        [ -f "$file" ] || continue
        [ "$(jq -r '.enabled' "$file" 2> /dev/null)" = "true" ] && dirname "$file"
    done
}

# api_field <api folder> <jq filter>: print a field of the API's api.json
api_field() {
    jq -r "$2" "$1/api.json"
}

# Folder of the enabled API named <name>
api_dir_by_name() {
    local dir
    for dir in $(enabled_apis); do
        [ "$(api_field "$dir" .name)" = "$1" ] && echo "$dir" && return 0
    done
    return 1
}

# Host name (without the domain) of an API for a competitor
api_host() {
    local dir=$1 username=$2 subdomain=$3
    local host
    host=$(api_field "$dir" .host)
    host=${host//\{subdomain\}/$subdomain}
    echo "${host//\{username\}/$username}"
}

# Folder holding a competitor's writable copy of the API's SQLite database
api_data_dir() {
    echo "$DATA_DIR/apis/$1/$2"
}

# Copy the initial SQLite database for each competitor, unless it already exists (a redeploy keeps data).
# With --reset, existing copies are replaced. Apache runs as www-data (uid 33) and SQLite needs to write
# next to the database (journal), so the whole folder belongs to it.
prepare_api_data() {
    local dir=$1 only_user=${2:-} reset=${3:-false}
    local name sqlite username data_dir
    name=$(api_field "$dir" .name)
    sqlite=$(api_field "$dir" '.sqlite // empty')

    for username in $(jq -r '.competitors[].username' "$CONFIG_DIR/main.json"); do
        [ -n "$only_user" ] && [ "$username" != "$only_user" ] && continue
        data_dir=$(api_data_dir "$name" "$username")
        mkdir -p "$data_dir"
        if [ -n "$sqlite" ] && { [ "$reset" = true ] || [ ! -f "$data_dir/$(basename "$sqlite")" ]; }; then
            rm -rf "${data_dir:?}"/*
            cp "$dir/$sqlite" "$data_dir/"
        fi
        chown -R 33:33 "$data_dir"
    done
}

# Write the compose file of every enabled API for every competitor (removed when no API is enabled)
generate_apis_compose() {
    local file=$1
    local dirs dir name host php_version document_root sqlite env_json username subdomain service

    mapfile -t dirs < <(enabled_apis)
    if [ ${#dirs[@]} -eq 0 ]; then
        rm -f "$file"
        return
    fi

    mkdir -p "$(dirname "$file")"
    echo "services:" > "$file"
    for dir in "${dirs[@]}"; do
        name=$(api_field "$dir" .name)
        php_version=$(api_field "$dir" ".php_version // \"$APIS_DEFAULT_PHP_VERSION\"")
        document_root=$(api_field "$dir" '.document_root // "."')
        sqlite=$(api_field "$dir" '.sqlite // empty')
        # Extra variables, as YAML lines ("      KEY: "value""); "$" is doubled so compose keeps it as-is
        env_json=$(api_field "$dir" '(.env // {}) | to_entries[] | "      \(.key): \(.value | gsub("\\$"; "$$") | tojson)"')

        while IFS=$'\t' read -r username subdomain; do
            service="${username}_${name}"
            host="$(api_host "$dir" "$username" "$subdomain").$DOMAIN"
            cat <<EOF >> "$file"
  ${service}:
    image: php:${php_version}-apache
    container_name: ${service}
    restart: always
    command: ["sh", "/usr/local/bin/start-apache.sh"]
    networks:
      - gitea
    environment:
      APACHE_DOCUMENT_ROOT: /var/www/api/${document_root}
      API_NAME: ${name}
      COMPETITOR: ${username}
      DB_PATH: /var/www/data/$(basename "${sqlite:-database.sqlite}")
${env_json}
    volumes:
      - "${dir}:/var/www/api:ro"
      - "$(api_data_dir "$name" "$username"):/var/www/data"
      - "${SERVICES_DIR}/$(basename "$(service_dir apis)")/start-apache.sh:/usr/local/bin/start-apache.sh:ro"
    labels:
      competition.api: "${name}"
      wud.watch: "false"
      traefik.enable: "true"
      traefik.http.routers.${service}.rule: Host(\`${host}\`)
      traefik.http.routers.${service}.entrypoints: ${ENTRYPOINT}
      traefik.http.routers.${service}.tls: "${ENABLE_HTTPS}"
      traefik.http.routers.${service}.middlewares: ${service}-cors
      traefik.http.middlewares.${service}-cors.headers.accessControlAllowOriginList: "*"
      traefik.http.middlewares.${service}-cors.headers.accessControlAllowMethods: GET,POST,PUT,PATCH,DELETE,OPTIONS
      traefik.http.middlewares.${service}-cors.headers.accessControlAllowHeaders: "*"
      traefik.http.middlewares.${service}-cors.headers.addVaryHeader: "true"
      traefik.http.services.${service}.loadbalancer.server.port: 80
EOF
        done < <(jq -r '.competitors[] | [.username, .subdomain] | @tsv' "$CONFIG_DIR/main.json")
    done

    cat <<EOF >> "$file"

networks:
  gitea:
    external: true
EOF
}

# Remove API containers that are not in the compose file anymore (API disabled or deleted).
# Compose's --remove-orphans can't be used: every service shares the same compose project.
remove_stale_api_containers() {
    local file=$1
    local wanted container
    wanted=" $( [ -f "$file" ] && docker compose -f "$file" config --services 2> /dev/null | tr '\n' ' ') "
    for container in $(docker ps -a --filter label=competition.api --format '{{.Names}}'); do
        if [[ "$wanted" != *" $container "* ]]; then
            log_info "Removing $container (API disabled or removed)"
            docker rm -f "$container" > /dev/null
        fi
    done
}

# Print one line per problem in the api.json files (called by validate_configuration, main.json is valid)
validate_apis() {
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
    jq -r --argjson apis "$apis_json" --argjson reserved "$(printf '%s\n' "${APIS_RESERVED_HOSTS[@]}" | jq -R . | jq -s .)" '
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
