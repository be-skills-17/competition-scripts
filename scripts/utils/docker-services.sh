#!/bin/bash

# Start a Docker Compose service
docker_compose() {
    local file="$1"
    docker compose -f $DOCKER_DIR/${file} up -d 
}

# Wait for Gitea to be ready
wait_for_gitea() {
    local retries=10
    local wait=5
    local count=0

    until curl -s http://localhost:3000/api/v1/version > /dev/null; do
        if [ $count -ge $retries ]; then
            echo "Gitea did not become ready in time."
            exit 1
        fi
        echo "Waiting for Gitea to be ready..."
        sleep $wait
        count=$((count + 1))
    done
}

# Start core infrastructure services
start_core_services() {
    echo "Starting Traefik..."
    docker_compose "traefik.yaml"
    
    echo "Starting Gitea..."
    docker_compose "gitea.yaml"
}

# Start runner service
start_runner_services() {
    echo "Starting Gitea Runner..."
    docker_compose "gitea-runner.yaml"
}

# Start database service
start_database_services() {
    echo "Starting MySQL..."
    docker_compose "mysql.yaml"
}

# Start supporting services
start_supporting_services() {
    echo "Starting Verdaccio..."
    docker_compose "verdaccio.yaml"
    
    echo "Starting WUD (What's Up Docker)..."
    docker_compose "wud.yaml"
}

# Start competitor containers
start_competitor_services() {
    echo "Starting competitor containers..."
    docker compose -f $DYNAMIC_DOCKER_DIR/competitors.yaml up -d 
}

# Configure Verdaccio permissions
configure_verdaccio_permissions() {
    chmod 777 -R ${DATA_DIR}/verdaccio
}
