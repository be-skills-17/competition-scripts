# shellcheck shell=bash
# Verdaccio: private npm registry

# Verdaccio runs as uid 10001 and must be able to write its storage
service_verdaccio_pre_init() {
    log_info "Configuring Verdaccio permissions..."
    mkdir -p "$DATA_DIR/verdaccio"
    chmod 777 -R "$DATA_DIR/verdaccio"
}
