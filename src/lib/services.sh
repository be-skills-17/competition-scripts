# Services live in services/<NN>-<name>/:
#   - NN is the start order (stop/down go in reverse order)
#   - compose.yaml is the service's compose file
#   - service.sh (optional) defines hooks named service_<name>_<hook>, loaded by initialize.sh:
#       compose_file  print the compose file path (default: the service's compose.yaml)
#       pre_init      init only, before the first "docker compose up" (generate files, prepare data dirs)
#       pre_up        before every "docker compose up" (init, restore, recreate): files the containers mount
#       wait_ready    after "docker compose up" (init, restore): return once the service answers
#       post_init     init only, once the service is ready (create users, import data...)
#       clean         clean only, after the containers are removed
#       validate      check-config and the valid_config filter: print one line per problem in the service's config
#       recreate_override <compose file> <container>
#                     recreate only: print compose YAML merged over the service's compose file (e.g. keep an image)
# Helpers used by the hooks and by the service's own commands go in services/<NN>-<name>/lib/*.sh.

# Service names in start order
service_names() {
    local dir
    for dir in "$SERVICES_DIR"/[0-9]*-*/; do
        [ -d "$dir" ] || continue
        dir=$(basename "$dir")
        echo "${dir#*-}"
    done
}

service_names_reversed() {
    service_names | tac
}

service_dir() {
    local dir
    for dir in "$SERVICES_DIR"/[0-9]*-"$1"/; do
        [ -d "$dir" ] && echo "${dir%/}" && return 0
    done
    return 1
}

# Folder of the files generated for a service (compose files, configs...): dynamic/<name>/.
# The core backs up and cleans dynamic/ as a whole, so a service never needs changes outside its own folder.
service_dynamic_dir() {
    echo "$DYNAMIC_DIR/$1"
}

# Call service_<name>_<hook> with the remaining arguments, if the service defines it
run_service_hook() {
    local name=$1 hook=$2
    shift 2
    local fn="service_${name//-/_}_${hook}"
    if declare -F "$fn" > /dev/null; then
        "$fn" "$@"
    fi
}

service_compose_file() {
    local file
    file=$(run_service_hook "$1" compose_file)
    echo "${file:-$(service_dir "$1")/compose.yaml}"
}

# Name of the service owning a compose file (empty if none)
service_name_for_file() {
    local name
    for name in $(service_names); do
        [ "$(service_compose_file "$name")" = "$1" ] && echo "$name" && return 0
    done
}

# Every compose file of the stack, in start order
compose_files() {
    local name
    for name in $(service_names); do
        service_compose_file "$name"
    done
}

compose_files_reversed() {
    compose_files | tac
}

# Run "docker compose -f <file> <args...>" on every existing compose file.
# --reverse goes from the last service down to the first (for stop/down).
compose_each() {
    local order=compose_files
    if [ "$1" = "--reverse" ]; then
        order="compose_files_reversed"
        shift
    fi

    local file
    # fd 3: docker compose must not read the file list from stdin
    while read -r file <&3; do
        [ -f "$file" ] || continue
        docker compose -f "$file" "$@"
    done 3< <($order)
}

# Returns 0 if at least one container of the project is running
project_is_running() {
    [ -n "$(docker ps -q --filter "label=com.docker.compose.project=$COMPOSE_PROJECT_NAME")" ]
}
