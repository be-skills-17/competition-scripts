initialize_configuration

# Each service: prepare (pre_init), start, wait until it answers, configure (post_init).
# Order matters: gitea's post_init creates the runner token, the API token and the registry login
# used by the runners and competitors services after it.
for name in $(service_names); do
    log_section "Service: $name"
    run_service_hook "$name" pre_init
    compose_file=$(service_compose_file "$name")
    # pre_init may decide there is nothing to start (e.g. no API enabled)
    if [ ! -f "$compose_file" ]; then
        log_info "Nothing to start"
        continue
    fi
    docker compose -f "$compose_file" up -d
    run_service_hook "$name" wait_ready
    run_service_hook "$name" post_init
done

export_environment_variables "$BASE_DIR/.env"

echo ""
log_success "All done! Competition environment is ready! 🎉"
