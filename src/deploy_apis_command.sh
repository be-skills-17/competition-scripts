# Can be run at any time: existing SQLite copies are kept, only changed containers are recreated.
# Code changes need no deploy at all, the code is mounted read-only in the containers.
log_section "Deploying APIs"
load_configuration
setup_protocol_vars

service_apis_pre_init

compose_file=$(service_apis_compose_file)
remove_stale_api_containers "$compose_file"

if [ -f "$compose_file" ]; then
    docker compose -f "$compose_file" up -d
    log_success "APIs deployed"
else
    log_warning "No API enabled in config/apis/ (set \"enabled\": true in an api.json)"
fi
