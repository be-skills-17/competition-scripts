# Save the values computed by init to .env. Paths are not saved: initialize.sh derives them from the
# script location, so the project can be moved or restored elsewhere.
export_environment_variables() {
    local output_file=${1:-$BASE_DIR/.env}

    log_info "Exporting environment variables to $output_file"

    cat <<EOF > "$output_file"
DOMAIN="$DOMAIN"
ENABLE_HTTPS="$ENABLE_HTTPS"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
MODULES="$MODULES"
GITEA_HOSTNAME="$GITEA_HOSTNAME"
MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD"
ENTRYPOINT="$ENTRYPOINT"
GITEA_PROTOCOL="$GITEA_PROTOCOL"
REGISTRY_PORT="$REGISTRY_PORT"
GITEA_URL="$GITEA_URL"
GITEA_TOKEN="$GITEA_TOKEN"
REGISTRATION_TOKEN="$REGISTRATION_TOKEN"
EOF
}

# Paths derived from $BASE_DIR (the script location)
set_paths() {
    export BASE_DIR
    export CONFIG_DIR=$BASE_DIR/config
    export SERVICES_DIR=$BASE_DIR/services
    export DATA_DIR=$BASE_DIR/data
    export BACKUP_DIR=$BASE_DIR/backups
    export LOCK_FILE=$BASE_DIR/competition.lock
    # Generated files: each service writes in dynamic/<service>/ (see service_dynamic_dir)
    export DYNAMIC_DIR=$BASE_DIR/dynamic
}

# Load .env, then set the paths again: .env files written by older versions (and old backups) still
# contain absolute paths, which must not override the current location
load_env_file() {
    local base_dir=$BASE_DIR
    if [ -f "$base_dir/.env" ]; then
        set -a
        # shellcheck disable=SC1091
        source "$base_dir/.env"
        set +a
    fi
    BASE_DIR=$base_dir
    set_paths

    if [ -n "$DOMAIN" ]; then
        export GITEA_URL=${GITEA_URL:-"$GITEA_PROTOCOL://git.$DOMAIN"}
    fi
}
