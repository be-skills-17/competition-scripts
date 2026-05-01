#!/bin/bash

source "$(dirname "$0")/logging.sh"

# Start a Docker Compose service
docker_compose() {
    local file="$1"
    log_info "Starting service from $file"
    docker compose -f $DOCKER_DIR/${file} up -d 
}

# Wait for Gitea to be ready
wait_for_gitea() {
    local retries=10
    local wait=5
    local count=0

    log_info "Waiting for Gitea to be ready..."
    until curl -s http://localhost:3000/api/v1/version > /dev/null; do
        if [ $count -ge $retries ]; then
            log_error "Gitea did not become ready in time."
            exit 1
        fi
        log_debug "Gitea health check attempt $((count + 1))/$retries"
        sleep $wait
        count=$((count + 1))
    done
    log_success "Gitea is ready"
}

# Start core infrastructure services
start_core_services() {
    log_section "Starting Core Infrastructure"
    log_subsection "Traefik"
    docker_compose "traefik.yaml"
    
    log_subsection "Gitea"
    docker_compose "gitea.yaml"
    log_success "Core infrastructure started"
}

# Start runner service
start_runner_services() {
    log_section "Starting Gitea Runner"
    docker_compose "gitea-runner.yaml"
    log_success "Gitea Runner started"
}

# Start database service
start_database_services() {
    log_section "Starting Database"
    docker_compose "mysql.yaml"
    log_success "MySQL started"
}

# Start supporting services
start_supporting_services() {
    log_section "Starting Supporting Services"
    log_subsection "Verdaccio (NPM Registry)"
    docker_compose "verdaccio.yaml"
    
    log_subsection "WUD (What's Up Docker)"
    docker_compose "wud.yaml"
    log_success "Supporting services started"
}

# Start competitor containers
start_competitor_services() {
    log_section "Starting Competitor Containers"
    docker compose -f $DYNAMIC_DOCKER_DIR/competitors.yaml up -d
    log_success "Competitor containers started"
}

# Configure Verdaccio permissions
configure_verdaccio_permissions() {
    log_info "Configuring Verdaccio permissions..."
    chmod 777 -R ${DATA_DIR}/verdaccio
    log_success "Verdaccio permissions configured"
}
