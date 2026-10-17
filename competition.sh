#!/bin/bash
export VERBOSE=false

ARGS=()
for arg in "$@"; do
  case $arg in
    -v|--verbose)
      export VERBOSE=true
      ;;
    *)
      ARGS+=("$arg")
      ;;
  esac
done
set -- "${ARGS[@]}"

if [ "$VERBOSE" = true ]; then
    export REDIRECT="/dev/stdout"
else
    export REDIRECT="/dev/null"
fi

# Check if the correct number of arguments are provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <ACTION [backup,clean,init,recreate,restore,setup,start,stop]>"
    echo "       $0 recreate <service|group> [<service|group> ...]"
    echo "       $0 clean [--no-backup]"
    echo "       $0 restore <backup file | latest>"
    exit 1
fi

ACTION=$1
shift

# Data files belong to container users (root, mysql 999, gitea 1000, verdaccio 10001), so every action
# runs as root: init creates them, backup/clean read them, restore gives them back their owners.
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root: sudo $0 $ACTION $*"
    exit 1
fi


if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1090
  source .env
  set +a
fi

#Defining absolute path for various directories
export BASE_DIR=$(pwd)
export CONFIG_DIR=$BASE_DIR/config
export SCRIPTS_DIR=$BASE_DIR/scripts/utils
export ACTIONS_DIR=$BASE_DIR/scripts/actions
export DOCKER_DIR=$BASE_DIR/docker
export DATA_DIR=$BASE_DIR/data

export COMPOSE_PROJECT_NAME="competition_scripts"
export COMPOSE_IGNORE_ORPHANS=true
# Defining dynamic directories, which will hold generated files
export DYNAMIC_DOCKER_DIR=$BASE_DIR/dynamic/docker
export DYNAMIC_FRAMEWORKS_DIR=$BASE_DIR/dynamic/frameworks

export LOCK_FILE=$BASE_DIR/competition.lock
export BACKUP_DIR=$BASE_DIR/backups

function is_already_initialized() {
    if [ -f "$LOCK_FILE" ]; then
        return 0
    else
        return 1
    fi
}


case $ACTION in
    clean)
        bash "$ACTIONS_DIR/clean.sh" "$@"
        ;;
    backup)
        if ! is_already_initialized; then
            echo "Competition is not initialized. Please run the 'init' action first."
            exit 1
        fi
        bash "$ACTIONS_DIR/backup.sh"
        ;;
    restore)
        bash "$ACTIONS_DIR/restore.sh" "$@"
        ;;
    init)
        if is_already_initialized; then
            echo "Competition is already initialized. To re-initialize, please run the 'clean' action first."
            exit 1
        fi
        bash "$ACTIONS_DIR/init.sh"
        ;;
    setup)
        bash "$ACTIONS_DIR/setup.sh"
        ;;
    start)
        if ! is_already_initialized; then
            echo "Competition is not initialized. Please run the 'init' action first."
            exit 1
        fi
        bash "$ACTIONS_DIR/start.sh"
        ;;
    stop)
        if ! is_already_initialized; then
            echo "Competition is not initialized. Please run the 'init' action first."
            exit 1
        fi
        bash "$ACTIONS_DIR/stop.sh"
        ;;
    recreate)
        if ! is_already_initialized; then
            echo "Competition is not initialized. Please run the 'init' action first."
            exit 1
        fi
        bash "$ACTIONS_DIR/recreate.sh" "$@"
        ;;
    *)
        echo "Invalid action: $ACTION"
        echo "Valid actions are: backup, clean, init, recreate, restore, setup, start, stop"
        exit 1
        ;;
esac