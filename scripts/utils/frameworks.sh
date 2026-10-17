#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

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
    
    run_with_spinner "Pulling nginx image..." docker pull nginx:latest
    docker login -u $USERNAME -p $PASSWORD git.$DOMAIN > /dev/null 2>&1
    log_success "Docker registry credentials configured"
}

# Clone and process frameworks repository, importing only allowed frameworks
import_all_frameworks() {
    log_section "Importing Frameworks"

    if [ -z "$TEMP_DIR" ] || [ "$TEMP_DIR" = "/" ]; then
        log_error "TEMP_DIR is empty, aborting"; exit 1
    fi

    if [ -z "$ALLOWED_FRAMEWORKS" ]; then
        log_warning "No allowed_frameworks configured, importing all frameworks"
    fi

    rm -rf "$TEMP_DIR"
    run_with_spinner "Cloning frameworks repository..." git clone "$FRAMEWORKS_REPO" "$TEMP_DIR" || exit 1

    cd "$TEMP_DIR" || exit 1
    rm -rf "$TEMP_DIR/.git"

    local imported=() failed=()
    for dir in */; do
        [ -d "$dir" ] || continue
        framework_name=$(basename "$dir")

        # Skip frameworks not in the allow list (exact, case-sensitive match)
        if [ -n "$ALLOWED_FRAMEWORKS" ] && [[ " $ALLOWED_FRAMEWORKS " != *" $framework_name "* ]]; then
            log_info "Skipping $framework_name (not in allowed_frameworks)"
            continue
        fi

        framework_path=$(realpath "$dir")
        log_subsection "Framework: $framework_name"
        if run_with_spinner "Importing $framework_name..." import_framework "$framework_path" "$framework_name"; then
            log_success "$framework_name imported"
            imported+=("$framework_name")
        else
            failed+=("$framework_name")
        fi
    done

    # Warn about allowed frameworks that don't exist in the repository
    for allowed in $ALLOWED_FRAMEWORKS; do
        [[ " ${imported[*]} ${failed[*]} " == *" $allowed "* ]] || log_warning "Allowed framework '$allowed' not found in repository"
    done

    log_success "Imported ${#imported[@]} framework(s): ${imported[*]}"
    [ ${#failed[@]} -eq 0 ] || log_error "Failed: ${failed[*]}"
    cd - > /dev/null
    [ ${#failed[@]} -eq 0 ]
}
