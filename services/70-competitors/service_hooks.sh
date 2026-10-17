# shellcheck shell=bash
# Competitors: one container per competitor and module, deployed by WUD from Gitea's registry

# The compose file is generated from config/main.json by pre_init
service_competitors_compose_file() {
    echo "$(service_dynamic_dir competitors)/compose.yaml"
}

# Gitea users, team membership, CI secrets, initial images and the compose file
service_competitors_pre_init() {
    initialize_competitors_config
    process_all_competitors "$CONFIG_FILE"
    finalize_docker_compose_config
}

service_competitors_clean() {
    log_subsection "Removing Competitor Images"
    local username
    for username in $(jq -r '.competitors[].username' "$CONFIG_DIR/main.json"); do
        log_info "Removing images for competitor: $username"
        # An image still used by a container can't be removed: warn, the clean goes on
        docker images -q --filter "reference=git.$DOMAIN/$username/*" | xargs -r docker rmi -f \
            || log_warning "Some images of $username could not be removed"
    done
    log_success "Competitor images removed"
}

# recreate_override <compose file> <container>: competitor images are bumped by WUD after the initial 1.0.0; keep
# the image currently running instead of rolling the competitor back to the tag written in the compose file
service_competitors_recreate_override() {
    local file=$1 svc=$2 running wanted
    running=$(docker inspect "$svc" --format '{{.Config.Image}}' 2> /dev/null)
    wanted=$(docker compose -f "$file" config --format json | jq -r --arg s "$svc" '.services[$s].image')
    if [ -n "$running" ] && [ "$running" != "$wanted" ]; then
        log_info "Keeping currently deployed image $running (compose file says $wanted)" >&2
        printf 'services:\n  %s:\n    image: %s\n' "$svc" "$running"
    fi
}
