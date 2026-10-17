# shellcheck shell=bash
# Gitea: git server, container registry for competitor images, CI with the runners

# Poll Gitea until it answers, returns 1 after the last retry
poll_gitea() {
    local retries=10
    local wait=5
    local count=0

    until curl -s http://localhost:3000/api/v1/version > /dev/null; do
        if [ $count -ge $retries ]; then
            return 1
        fi
        log_debug "Gitea health check attempt $((count + 1))/$retries"
        sleep $wait
        count=$((count + 1))
    done
}

# Wait for Gitea to be ready
wait_for_gitea() {
    if ! run_with_spinner "Waiting for Gitea to be ready..." poll_gitea; then
        log_error "Gitea did not become ready in time."
        exit 1
    fi
    log_success "Gitea is ready"
}

service_gitea_wait_ready() {
    wait_for_gitea
}

# Admin user, runner token (used by the runners service), API token, organizations, frameworks templates
# and registry login (used by the competitors service to push their initial images)
service_gitea_post_init() {
    log_subsection "Admin user"
    create_admin_user "$USERNAME" "$PASSWORD"
    generate_registration_token

    log_subsection "Gitea access"
    if ! GITEA_TOKEN=$(create_pat); then
        log_error "$GITEA_TOKEN"
        exit 1
    fi
    export GITEA_TOKEN
    setup_organizations_and_teams

    import_all_frameworks
    setup_docker_registry_credentials
}
