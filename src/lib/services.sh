# Every compose file of the stack, in start order: traefik creates the "gitea" network the others join,
# and competitor images are pulled from Gitea's registry, so Gitea comes before them.
compose_files() {
    printf '%s\n' \
        "$DOCKER_DIR/traefik.yaml" \
        "$DOCKER_DIR/gitea.yaml" \
        "$DOCKER_DIR/gitea-runner.yaml" \
        "$DOCKER_DIR/mysql.yaml" \
        "$DOCKER_DIR/verdaccio.yaml" \
        "$DOCKER_DIR/wud.yaml" \
        "$DYNAMIC_DOCKER_DIR/competitors.yaml"
}

# Run "docker compose -f <file> <args...>" on every existing compose file.
# --reverse goes from competitors down to traefik (for stop/down).
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

compose_files_reversed() {
    compose_files | tac
}

# Returns 0 if at least one container of the project is running
project_is_running() {
    [ -n "$(docker ps -q --filter "label=com.docker.compose.project=$COMPOSE_PROJECT_NAME")" ]
}
