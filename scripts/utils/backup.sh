#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# Everything needed to bring an environment back, relative to $BASE_DIR.
# Competitor images live in Gitea's container registry, so they are inside data/gitea.
BACKUP_ITEMS=(data config dynamic/docker .env competition.lock)

# Compose files in start order (traefik creates the "gitea" network used by the others)
COMPOSE_START_ORDER=(
    "$DOCKER_DIR/traefik.yaml"
    "$DOCKER_DIR/gitea.yaml"
    "$DOCKER_DIR/gitea-runner.yaml"
    "$DOCKER_DIR/mysql.yaml"
    "$DOCKER_DIR/verdaccio.yaml"
    "$DOCKER_DIR/wud.yaml"
    "$DYNAMIC_DOCKER_DIR/competitors.yaml"
)

# Returns 0 if at least one container of the project is running
project_is_running() {
    [ -n "$(docker ps -q --filter "label=com.docker.compose.project=$COMPOSE_PROJECT_NAME")" ]
}

# Create a tar.gz of BACKUP_ITEMS in $BACKUP_DIR. Services must be stopped for a consistent MySQL copy.
# Sets LAST_BACKUP_FILE (empty when there was nothing to back up).
create_backup_archive() {
    local label=${1:-manual}
    local items=() item
    LAST_BACKUP_FILE=""

    for item in "${BACKUP_ITEMS[@]}"; do
        [ -e "$BASE_DIR/$item" ] && items+=("$item")
    done

    if [ ! -d "$DATA_DIR" ]; then
        log_warning "No data directory, nothing to back up"
        return 0
    fi

    # Archives contain .env, Gitea and MySQL data: readable by root only
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
    LAST_BACKUP_FILE="$BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S)-$label.tar.gz"

    log_info "Creating $LAST_BACKUP_FILE"
    # --numeric-owner: keep container uids (mysql 999, gitea 1000, verdaccio 10001) even if the host maps
    # those numbers to other names or the backup is restored on another machine
    if ! (umask 077 && tar --numeric-owner -czpf "$LAST_BACKUP_FILE" -C "$BASE_DIR" "${items[@]}"); then
        log_error "Backup failed"
        rm -f "$LAST_BACKUP_FILE"
        return 1
    fi
    log_success "Backup created ($(du -h "$LAST_BACKUP_FILE" | cut -f1)): $LAST_BACKUP_FILE"
}
