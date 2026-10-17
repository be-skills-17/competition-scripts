# Load and export configuration from main.json
load_configuration() {
    local config_file=$CONFIG_DIR/main.json
    log_debug "Loading configuration from $config_file"
    
    export DOMAIN=$(jq -r '.domain' "$config_file")
    export ENABLE_HTTPS=$(jq -r '.enable_https' "$config_file")
    export USERNAME=$(jq -r '.username' "$config_file")
    export PASSWORD=$(jq -r '.password' "$config_file")
    export MODULES=$(jq -r '.modules | join(" ")' "$config_file")
    export FRAMEWORKS_REPO=$(jq -r '.frameworks.frameworks_repo' "$config_file")
    export ALLOWED_FRAMEWORKS=$(jq -r '.frameworks.allowed_frameworks | join(" ")' "$config_file")
}

# Setup HTTP/HTTPS related variables
setup_protocol_vars() {
    if [ "$ENABLE_HTTPS" = "true" ]; then
        export ENTRYPOINT=websecure
        export GITEA_PROTOCOL=https
        export REGISTRY_PORT=443
    else
        export ENTRYPOINT=web
        export GITEA_PROTOCOL=http
        export REGISTRY_PORT=5000
    fi
}

# Setup service hostnames and credentials
setup_service_vars() {
    export GITEA_HOSTNAME=$DOMAIN
    export MYSQL_ROOT_PASSWORD=$PASSWORD
    export GITEA_URL="$GITEA_PROTOCOL://git.$DOMAIN"
}

# Setup directory variables
setup_directory_vars() {
    mkdir -p ${DYNAMIC_DOCKER_DIR} ${DYNAMIC_FRAMEWORKS_DIR}
    export CONFIG_FILE=$CONFIG_DIR/main.json
}

# Main configuration initialization
initialize_configuration() {
    log_section "Initializing Configuration"
    load_configuration
    log_debug "Loaded configuration from main.json"
    setup_protocol_vars
    log_debug "Setup protocol variables (HTTPS: $ENABLE_HTTPS)"
    setup_service_vars
    log_debug "Setup service variables"
    setup_directory_vars
    log_debug "Setup directory variables"
    touch "$LOCK_FILE"
    log_success "Configuration initialized"
}

# Print one line per problem in config/main.json (nothing when it is valid).
# Usernames, subdomains and modules end up in DNS names, container names, image paths and database
# names; passwords are inserted as-is in SQL and JSON (quotes and backslashes would break them) and read
# back as tab-separated values (tabs and other control characters would be mangled).
validate_configuration() {
    local config_file=$CONFIG_DIR/main.json

    if [ ! -f "$config_file" ]; then
        echo "$config_file not found"
        return
    fi
    if ! jq empty "$config_file" 2> /dev/null; then
        echo "not valid JSON: $(jq empty "$config_file" 2>&1 | head -n1)"
        return
    fi

    jq -r '
        def text: type == "string" and length > 0;
        def name: text and test("^[a-z0-9][a-z0-9-]*$");
        def password: text and (test("[\"'"'"'\\\\[:cntrl:]]") | not);
        def check(cond; message): if cond then empty else message end;
        def duplicates(f): [.[] | f] | group_by(.) | map(select(length > 1) | .[0]) | .[];

        check(.domain | text; "domain: required (e.g. \"local.skill17.com\")"),
        check(.enable_https | type == "boolean"; "enable_https: must be true or false"),
        check(.username | name; "username: required, lowercase letters, digits and dashes only"),
        check(.password | password; "password: required, without quotes, backslashes or control characters (tab...)"),
        check(.modules | type == "array" and length > 0 and all(.[]; name);
            "modules: required, a non-empty list of names (lowercase letters, digits and dashes)"),
        check(.frameworks.frameworks_repo | text; "frameworks.frameworks_repo: required (git URL)"),
        check(.frameworks.allowed_frameworks | . == null or (type == "array" and all(.[]; text));
            "frameworks.allowed_frameworks: must be a list of framework names"),

        if (.competitors | type == "array" and length > 0) | not then
            "competitors: required, a non-empty list"
        else
            (.competitors | to_entries[] | .key as $i | .value |
                check(.username | name; "competitors[\($i)].username: required, lowercase letters, digits and dashes only"),
                check(.password | password; "competitors[\($i)].password: required, without quotes, backslashes or control characters (tab...)"),
                check(.subdomain | name; "competitors[\($i)].subdomain: required, lowercase letters, digits and dashes only"),
                check(.name | . == null or text; "competitors[\($i)].name: must be a non-empty string if set")),
            (.competitors | duplicates(.username) | "competitors: username \"\(.)\" is used more than once"),
            (.competitors | duplicates(.subdomain) | "competitors: subdomain \"\(.)\" is used more than once")
        end
    ' "$config_file"
}
