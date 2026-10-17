# shellcheck shell=bash
# APIs: native PHP APIs from config/apis/, one container per API and competitor (see src/lib/apis.sh)

# The compose file is generated from the enabled APIs by pre_init (and deploy-apis)
service_apis_compose_file() {
    echo "$DYNAMIC_DOCKER_DIR/apis.yaml"
}

# SQLite copies and compose file; no compose file at all when no API is enabled
service_apis_pre_init() {
    local dir
    for dir in $(enabled_apis); do
        log_info "API $(api_field "$dir" .name) ($(basename "$dir"))"
        prepare_api_data "$dir"
    done
    generate_apis_compose "$(service_apis_compose_file)"
}

# Containers of APIs disabled since the last deploy are not in the compose file anymore
service_apis_clean() {
    docker ps -aq --filter label=competition.api | xargs -r docker rm -f > /dev/null
}
