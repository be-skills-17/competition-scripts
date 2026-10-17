# Runs before argument parsing, for every command (including --help)

# .env holds the values computed by init (domain, credentials, tokens...)
BASE_DIR=$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)
if [ -f "$BASE_DIR/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source "$BASE_DIR/.env"
    set +a
fi

# Paths are always derived from the script location, never from .env or the current directory
export BASE_DIR
export CONFIG_DIR=$BASE_DIR/config
export DOCKER_DIR=$BASE_DIR/docker
export DATA_DIR=$BASE_DIR/data
export BACKUP_DIR=$BASE_DIR/backups
export LOCK_FILE=$BASE_DIR/competition.lock
# Generated files
export DYNAMIC_DOCKER_DIR=$BASE_DIR/dynamic/docker
export DYNAMIC_FRAMEWORKS_DIR=$BASE_DIR/dynamic/frameworks

export COMPOSE_PROJECT_NAME="competition_scripts"
export COMPOSE_IGNORE_ORPHANS=true

if [ -n "$DOMAIN" ]; then
    export GITEA_URL=${GITEA_URL:-"$GITEA_PROTOCOL://git.$DOMAIN"}
fi

export VERBOSE=false
export REDIRECT=/dev/null
