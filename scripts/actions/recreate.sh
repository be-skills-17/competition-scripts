#!/bin/bash

# Recreate one or more services individually, without touching the rest of the stack.
# Usage: competition.sh recreate <service|group> [<service|group> ...]

source "$SCRIPTS_DIR/logging.sh"

# GITEA_URL is not stored in .env, rebuild it from the stored protocol/domain
export GITEA_URL=${GITEA_URL:-"$GITEA_PROTOCOL://git.$DOMAIN"}

COMPOSE_FILES=(
    "$DOCKER_DIR/traefik.yaml"
    "$DOCKER_DIR/gitea.yaml"
    "$DOCKER_DIR/gitea-runner.yaml"
    "$DOCKER_DIR/mysql.yaml"
    "$DOCKER_DIR/verdaccio.yaml"
    "$DOCKER_DIR/wud.yaml"
    "$DYNAMIC_DOCKER_DIR/competitors.yaml"
)

# Maps "service name" -> "compose file"
declare -A SERVICE_FILE
# Maps "group name" (compose file basename) -> "compose file"
declare -A GROUP_FILE

build_service_map() {
    local file group svc
    for file in "${COMPOSE_FILES[@]}"; do
        [ -f "$file" ] || continue
        group=$(basename "$file" .yaml)
        GROUP_FILE[$group]=$file
        for svc in $(docker compose -f "$file" config --services 2>/dev/null); do
            SERVICE_FILE[$svc]=$file
        done
    done
    # Friendly aliases
    [ -n "${GROUP_FILE[gitea-runner]}" ] && GROUP_FILE[runners]=${GROUP_FILE[gitea-runner]}
}

print_available() {
    echo "Available services:"
    local file svc
    for file in "${COMPOSE_FILES[@]}"; do
        [ -f "$file" ] || continue
        echo -n "  $(basename "$file" .yaml): "
        docker compose -f "$file" config --services 2>/dev/null | tr '\n' ' '
        echo ""
    done
    echo ""
    echo "A group name (e.g. 'mysql', 'runners', 'competitors') recreates every service of that file."
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

# Older deployments kept Gitea's /data (repositories, packages/registry, avatars...) in an anonymous
# Docker volume. Copy it to $DATA_DIR/gitea before switching to the bind mount, otherwise all of it is lost.
migrate_gitea_data() {
    local volume image
    docker container inspect gitea > /dev/null 2>&1 || return 0
    volume=$(docker inspect gitea --format '{{range .Mounts}}{{if and (eq .Destination "/data") (eq .Type "volume")}}{{.Name}}{{end}}{{end}}')
    [ -n "$volume" ] || return 0

    if [ -d "$DATA_DIR/gitea" ] && [ -n "$(ls -A "$DATA_DIR/gitea" 2>/dev/null)" ]; then
        log_error "Gitea currently uses volume '$volume' but $DATA_DIR/gitea is not empty."
        log_error "Refusing to choose between them; move one of them away and retry."
        exit 1
    fi

    log_info "Migrating Gitea data from anonymous volume '$volume' to $DATA_DIR/gitea"
    image=$(docker inspect gitea --format '{{.Config.Image}}')
    docker stop gitea > /dev/null
    if ! docker run --rm --entrypoint sh \
        -v "$volume:/from:ro" -v "$DATA_DIR/gitea:/to" \
        "$image" -c 'cp -a /from/. /to/'; then
        log_error "Copy failed, restarting the old Gitea container untouched"
        docker start gitea > /dev/null
        exit 1
    fi
    log_success "Gitea data migrated (old volume '$volume' kept as a backup, remove it with: docker volume rm $volume)"
}

recreate_service() {
    local file=$1 svc=$2
    local files=(-f "$file")
    local override=""

    log_subsection "$svc"

    [ "$svc" = "gitea" ] && migrate_gitea_data

    # Competitor images are bumped by WUD after the initial 1.0.0; keep the image currently running
    # instead of rolling the competitor back to the tag written in competitors.yaml.
    if [ "$file" = "$DYNAMIC_DOCKER_DIR/competitors.yaml" ]; then
        local running wanted
        running=$(docker inspect "$svc" --format '{{.Config.Image}}' 2>/dev/null)
        wanted=$(docker compose -f "$file" config --format json | jq -r --arg s "$svc" '.services[$s].image')
        if [ -n "$running" ] && [ "$running" != "$wanted" ]; then
            log_info "Keeping currently deployed image $running (compose file says $wanted)"
            override=$(mktemp --suffix=.yaml)
            printf 'services:\n  %s:\n    image: %s\n' "$svc" "$running" > "$override"
            files+=(-f "$override")
        fi
    fi

    remove_untracked_container "$file" "$svc"
    docker compose "${files[@]}" up -d --no-deps --force-recreate "$svc"
    local status=$?
    [ -n "$override" ] && rm -f "$override"
    return $status
}

if [ "$#" -lt 1 ]; then
    echo "Usage: competition.sh recreate <service|group> [<service|group> ...]"
    echo ""
    print_available
    exit 1
fi

build_service_map

for target in "$@"; do
    if [ -z "${SERVICE_FILE[$target]}" ] && [ -z "${GROUP_FILE[$target]}" ]; then
        log_error "Unknown service or group: $target"
        echo ""
        print_available
        exit 1
    fi
done

log_section "Recreating Services"
failed=0
for target in "$@"; do
    if [ -n "${SERVICE_FILE[$target]}" ]; then
        recreate_service "${SERVICE_FILE[$target]}" "$target" || failed=1
    elif [ -n "${GROUP_FILE[$target]}" ]; then
        file=${GROUP_FILE[$target]}
        for svc in $(docker compose -f "$file" config --services); do
            recreate_service "$file" "$svc" || failed=1
        done
    fi
done

if [ "$failed" -ne 0 ]; then
    log_error "Some services failed to be recreated"
    exit 1
fi
log_success "Done"
