#!/bin/bash

# Restore a backup created by the backup/clean actions.
# Usage: competition.sh restore <backup file | name in backups/ | latest>
# The current environment is cleaned first (which itself creates a backup of it).

source "$SCRIPTS_DIR/logging.sh"
source "$SCRIPTS_DIR/backup.sh"
source "$SCRIPTS_DIR/docker-services.sh"

list_backups() {
    echo "Available backups in $BACKUP_DIR:"
    ls -1t "$BACKUP_DIR"/backup-*.tar.gz 2>/dev/null | xargs -r -n1 basename | sed 's/^/  /'
}

if [ "$#" -ne 1 ]; then
    echo "Usage: competition.sh restore <backup file | latest>"
    echo ""
    list_backups
    exit 1
fi

if [ "$1" = "latest" ]; then
    archive=$(ls -1t "$BACKUP_DIR"/backup-*.tar.gz 2>/dev/null | head -n1)
elif [ -f "$1" ]; then
    archive=$(realpath "$1")
else
    archive="$BACKUP_DIR/$(basename "$1")"
fi

if [ -z "$archive" ] || [ ! -f "$archive" ]; then
    log_error "Backup not found: $1"
    echo ""
    list_backups
    exit 1
fi

log_section "Restoring $(basename "$archive")"

log_subsection "Checking archive"
contents=$(tar -tzf "$archive" 2>/dev/null) || { log_error "Archive is corrupted or unreadable"; exit 1; }
if ! grep -q '^data/' <<< "$contents" || ! grep -qx '.env' <<< "$contents"; then
    log_error "This archive does not look like a competition backup (missing data/ or .env)"
    exit 1
fi
log_success "Archive OK"

# Wipe the current environment; clean.sh backs it up first so nothing is lost
bash "$ACTIONS_DIR/clean.sh" || { log_error "Clean failed, aborting restore"; exit 1; }

log_section "Extracting Backup"
tar --numeric-owner -xzpf "$archive" -C "$BASE_DIR" || { log_error "Extraction failed"; exit 1; }

# .env stores absolute paths; fix them if the project was moved since the backup
old_base=$(sed -n 's/^BASE_DIR="\(.*\)"$/\1/p' "$BASE_DIR/.env")
if [ -n "$old_base" ] && [ "$old_base" != "$BASE_DIR" ]; then
    log_info "Updating paths in .env: $old_base -> $BASE_DIR"
    sed -i "s#$old_base#$BASE_DIR#g" "$BASE_DIR/.env"
fi
touch "$LOCK_FILE"
log_success "Files restored"

set -a
source "$BASE_DIR/.env"
set +a
export GITEA_URL=${GITEA_URL:-"$GITEA_PROTOCOL://git.$DOMAIN"}

log_section "Starting Services"
for file in "${COMPOSE_START_ORDER[@]}"; do
    log_subsection "$(basename "$file" .yaml)"
    docker compose -f "$file" up -d
    # Competitor images are pulled from Gitea's registry, it must be up before them
    [ "$(basename "$file")" = "gitea.yaml" ] && wait_for_gitea
done

echo ""
log_success "Restore complete! 🎉"
