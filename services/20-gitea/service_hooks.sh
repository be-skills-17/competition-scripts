# shellcheck shell=bash
# Gitea: git server, container registry for competitor images, CI with the runners

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

# config/main.json "frameworks" section (validate hook)
service_gitea_validate() {
    jq -r '
        def text: type == "string" and length > 0;
        def check(cond; message): if cond then empty else message end;
        check(.frameworks.frameworks_repo | text; "frameworks.frameworks_repo: required (git URL)"),
        check(.frameworks.allowed_frameworks | . == null or (type == "array" and all(.[]; text));
            "frameworks.allowed_frameworks: must be a list of framework names")
    ' "$CONFIG_DIR/main.json"
}
