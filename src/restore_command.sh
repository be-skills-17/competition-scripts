# The current environment is cleaned first, which itself creates a backup of it
if [ -z "${args[backup]}" ]; then
    list_backups
    exit 0
fi

archive=$(resolve_backup "${args[backup]}")
if [ -z "$archive" ]; then
    log_error "Backup not found: ${args[backup]}"
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

clean_environment true

log_section "Extracting Backup"
run_with_spinner "Extracting $(basename "$archive")..." \
    tar --numeric-owner -xzpf "$archive" -C "$BASE_DIR" || exit 1

# .env stores absolute paths; fix them if the project was moved since the backup
old_base=$(sed -n 's/^BASE_DIR="\(.*\)"$/\1/p' "$BASE_DIR/.env")
if [ -n "$old_base" ] && [ "$old_base" != "$BASE_DIR" ]; then
    log_info "Updating paths in .env: $old_base -> $BASE_DIR"
    sed -i "s#$old_base#$BASE_DIR#g" "$BASE_DIR/.env"
fi
touch "$LOCK_FILE"
log_success "Files restored"

set -a
# shellcheck disable=SC1091
source "$BASE_DIR/.env"
set +a
export GITEA_URL=${GITEA_URL:-"$GITEA_PROTOCOL://git.$DOMAIN"}

log_section "Starting Services"
# Competitor images are pulled from Gitea's registry: each service waits for the previous ones
for name in $(service_names); do
    log_subsection "$name"
    docker compose -f "$(service_compose_file "$name")" up -d < /dev/null
    run_service_hook "$name" wait_ready
done

echo ""
log_success "Restore complete! 🎉"
