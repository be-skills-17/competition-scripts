#!/bin/bash

source "$(dirname "$0")/logging.sh"

# Import a framework from a local path
import_framework() {
    local framework_path=$1
    local framework_name=$2
    
    # Check if .npmrc exists and replace ##DOMAIN## with actual domain
    if [ -f "$framework_path/.npmrc" ]; then
        log_info "Found .npmrc in $framework_name, replacing ##DOMAIN## with $DOMAIN"
        sed -i "s/##DOMAIN##/$DOMAIN/g" "$framework_path/.npmrc"
        log_info ".npmrc updated with domain: $DOMAIN"
    fi
    
    $SCRIPTS_DIR/import_framework.sh "$framework_path" "$framework_name"
}

# Setup Docker credentials for registry
setup_docker_registry_credentials() {
    log_info "Setting up Docker registry credentials..."
    
    docker pull nginx:latest > /dev/null 2>&1
    docker login -u $USERNAME -p $PASSWORD git.$DOMAIN > /dev/null 2>&1
    log_success "Docker registry credentials configured"
}

# Clone and process frameworks repository
import_all_frameworks() {
    log_section "Importing Frameworks"

    if [ -z "$TEMP_DIR" ] || [ "$TEMP_DIR" = "/" ]; then
        log_error "TEMP_DIR is empty, aborting"; exit 1
    fi

    log_info "Cloning frameworks repository..."
    rm -rf "$TEMP_DIR"
    git clone "$FRAMEWORKS_REPO" "$TEMP_DIR" || { log_error "Clone failed"; exit 1; }

    cd "$TEMP_DIR" || exit 1
    rm -rf "$TEMP_DIR/.git"

    for dir in $(find . -maxdepth 1 -type d -not -path '*/.*' -not -path '.'); do
        framework_name=$(basename "$dir")
        framework_path=$(realpath "$dir")
        log_subsection "Framework: $framework_name"
        import_framework "$framework_path" "$framework_name"
    done

    log_success "All frameworks imported"
    cd - > /dev/null
}
