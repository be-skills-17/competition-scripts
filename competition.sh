#!/bin/bash
export VERBOSE=false

for arg in "$@"; do
  case $arg in
    -v|--verbose)
      export VERBOSE=true
      shift 
      ;;
  esac
done

if [ "$VERBOSE" = true ]; then
    export REDIRECT="/dev/stdout"
else
    export REDIRECT="/dev/null"
fi

# Check if the correct number of arguments are provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <ACTION [clean,init,setup,start,stop]>"
    exit 1
fi

ACTION=$1


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

function is_already_initialized() {
    if [ -f "$LOCK_FILE" ]; then
        return 0
    else
        return 1
    fi
}


case $ACTION in
    clean)
        bash "$ACTIONS_DIR/clean.sh"
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
    *)
        echo "Invalid action: $ACTION"
        echo "Valid actions are: clean, init, setup, start, stop"
        exit 1
        ;;
esac