# Can be run at any time: existing SQLite copies are kept, only changed containers are recreated.
# Code changes need no deploy at all, the code is mounted read-only in the containers.
log_section "Deploying APIs"
load_configuration
setup_protocol_vars

service_apis_pre_init

compose_file=$(service_apis_compose_file)
remove_stale_api_containers "$compose_file"

# Other services may show or use the APIs (the portal lists each competitor's API URLs): let each one
# regenerate its files. pre_up is meant to be run again at any time.
for name in $(service_names); do
    [ "$name" = apis ] || run_service_hook "$name" pre_up
done

if [ -f "$compose_file" ]; then
    docker compose -f "$compose_file" up -d
    log_success "APIs deployed"
else
    log_warning "No API enabled in config/apis/ (set \"enabled\": true in an api.json)"
fi
