# Recreate services individually, without touching the rest of the stack

# Maps "service name" -> "compose file"
declare -gA SERVICE_FILE
# Maps "group name" (service name) -> "compose file"
declare -gA GROUP_FILE

build_service_map() {
    local name file svc
    for name in $(service_names); do
        file=$(service_compose_file "$name")
        [ -f "$file" ] || continue
        GROUP_FILE[$name]=$file
        for svc in $(docker compose -f "$file" config --services 2>/dev/null < /dev/null); do
            SERVICE_FILE[$svc]=$file
        done
    done
}

print_available() {
    echo "Available services:"
    local name file
    for name in $(service_names); do
        file=$(service_compose_file "$name")
        [ -f "$file" ] || continue
        echo -n "  $name: "
        docker compose -f "$file" config --services 2>/dev/null | tr '\n' ' '
        echo ""
    done
    echo ""
    echo "A group name (e.g. 'mysql', 'runners', 'competitors') recreates every container of that service."
    echo "An exact service name always takes precedence over a group name (e.g. 'gitea' only recreates the gitea container)."
}

# Remove a container that holds the service's container_name but is no longer tracked by compose
# (e.g. a competitor container redeployed by WUD), otherwise "up" fails with a name conflict.
remove_untracked_container() {
    local file=$1 svc=$2
    local name
    name=$(docker compose -f "$file" config --format json 2>/dev/null | jq -r --arg s "$svc" '.services[$s].container_name // empty')
    [ -n "$name" ] || return 0
    docker container inspect "$name" > /dev/null 2>&1 || return 0
    if [ -z "$(docker compose -f "$file" ps -a -q "$svc" 2>/dev/null)" ]; then
        log_warning "Container '$name' exists but is not tracked by compose, removing it"
        docker rm -f "$name" > /dev/null
    fi
}

recreate_service() {
    local file=$1 svc=$2
    local files=(-f "$file")
    local override=""

    log_subsection "$svc"

    # A service may adjust the container being recreated (recreate_override hook prints compose YAML)
    local name content
    name=$(service_name_for_file "$file")
    content=$(run_service_hook "$name" recreate_override "$file" "$svc")
    if [ -n "$content" ]; then
        override=$(mktemp --suffix=.yaml)
        echo "$content" > "$override"
        files+=(-f "$override")
    fi

    run_service_hook "$name" pre_up
    remove_untracked_container "$file" "$svc"
    docker compose "${files[@]}" up -d --no-deps --force-recreate "$svc"
    local status=$?
    [ -n "$override" ] && rm -f "$override"
    return $status
}
