# Everything needed to bring an environment back, relative to $BASE_DIR.
# Competitor images live in Gitea's container registry, so they are inside data/gitea.
BACKUP_ITEMS=(data config dynamic/docker dynamic/dashboard .env competition.lock)

# Write the given items (relative to $BASE_DIR) into a root-only archive.
# --numeric-owner: keep container uids (mysql 999, gitea 1000, verdaccio 10001) even if the host maps
# those numbers to other names or the backup is restored on another machine
write_archive() {
    local file=$1
    shift
    (umask 077 && tar --numeric-owner -czpf "$file" -C "$BASE_DIR" "$@")
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

    if ! run_with_spinner "Creating $LAST_BACKUP_FILE..." write_archive "$LAST_BACKUP_FILE" "${items[@]}"; then
        rm -f "$LAST_BACKUP_FILE"
        return 1
    fi
    log_success "Backup created ($(du -h "$LAST_BACKUP_FILE" | cut -f1)): $LAST_BACKUP_FILE"
}

list_backups() {
    echo "Available backups in $BACKUP_DIR:"
    ls -1t "$BACKUP_DIR"/backup-*.tar.gz 2>/dev/null | xargs -r -n1 basename | sed 's/^/  /'
}

# Print the archive path for a file path, a file name in $BACKUP_DIR, or "latest"
resolve_backup() {
    local name=$1
    if [ "$name" = "latest" ]; then
        ls -1t "$BACKUP_DIR"/backup-*.tar.gz 2>/dev/null | head -n1
    elif [ -f "$name" ]; then
        realpath "$name"
    elif [ -f "$BACKUP_DIR/$(basename "$name")" ]; then
        echo "$BACKUP_DIR/$(basename "$name")"
    fi
}
