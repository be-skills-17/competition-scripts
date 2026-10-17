errors=$(validate_configuration)

if [ -n "$errors" ]; then
    log_error "Invalid config/main.json:"
    sed 's/^/  - /' <<< "$errors" >&2
    exit 1
fi
log_success "config/main.json is valid"
