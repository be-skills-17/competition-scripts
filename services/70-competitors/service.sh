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
