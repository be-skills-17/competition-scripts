# shellcheck shell=bash
# Verdaccio: private npm registry (helpers and npm proxy modes: lib/verdaccio.sh)

# Verdaccio runs as uid 10001 and must be able to write its storage
service_verdaccio_pre_init() {
    log_info "Configuring Verdaccio permissions..."
    mkdir -p "$DATA_DIR/verdaccio"
    chmod 777 -R "$DATA_DIR/verdaccio"
    write_verdaccio_config on
}

service_verdaccio_wait_ready() {
    wait_for_verdaccio
}

# npm is cut off by default: the packages of config/main.json are cached, then npmjs is cut off.
# A failure does not stop init (the proxy stays on and the error says what to do).
service_verdaccio_post_init() {
    log_subsection "npm packages"
    prefetch_npm_packages || true
}
