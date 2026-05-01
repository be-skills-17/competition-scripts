#!/bin/bash

# Load and export configuration from main.json
load_configuration() {
    local config_file=$(realpath "config/main.json")
    
    export DOMAIN=$(jq -r '.domain' "$config_file")
    export ENABLE_HTTPS=$(jq -r '.enable_https' "$config_file")
    export USERNAME=$(jq -r '.username' "$config_file")
    export PASSWORD=$(jq -r '.password' "$config_file")
    export MODULES=$(jq -r '.modules | join(" ")' "$config_file")
    export FRAMEWORKS_REPO=$(jq -r '.frameworks_repo' "$config_file")
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
    export TEMP_DIR="/tmp/framework-templates"
    export CONFIG_FILE=$(realpath "config/main.json")
    export IMPORT_SCRIPT=$(realpath "./scripts/utils/import_framework.sh")
    
    mkdir -p ${DYNAMIC_DOCKER_DIR} ${DYNAMIC_FRAMEWORKS_DIR}
}

# Initialize lock file
create_lock_file() {
    touch $LOCK_FILE
}

# Main configuration initialization
initialize_configuration() {
    load_configuration
    setup_protocol_vars
    setup_service_vars
    setup_directory_vars
    create_lock_file
}
