errors=$(validate_configuration)

if [ -n "$errors" ]; then
    log_error "Invalid configuration:"
    sed 's/^/  - /' <<< "$errors" >&2
    exit 1
fi
log_success "Configuration is valid (config/main.json and every service)"
