#!/bin/bash

source "$(dirname "$0")/logging.sh"

# Import a framework from a local path
import_framework() {
    local framework_path=$1
    local framework_name=$2
    
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
    log_info "Cloning frameworks repository..."
    git clone "$FRAMEWORKS_REPO" "$TEMP_DIR"

    cd "$TEMP_DIR" || exit
    rm -rf .git

    for dir in $(find . -maxdepth 1 -type d -not -path '*/.*' -not -path '.'); do
        framework_name=$(basename "$dir")
        framework_path=$(realpath "$dir")
        
        log_subsection "Framework: $framework_name"
        import_framework "$framework_path" "$framework_name"
    done
    
    log_success "All frameworks imported"
    cd - > /dev/null
}
