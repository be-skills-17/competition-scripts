# Bashly filters: printing a message stops the command with that error

# Data files belong to container users (root, mysql 999, gitea 1000, verdaccio 10001), so every command
# runs as root: init creates them, backup/clean read them, restore gives them back their owners.
filter_root() {
    [ "$EUID" -eq 0 ] || echo "This command must be run as root: sudo $0 ..."
}

filter_initialized() {
    [ -f "$LOCK_FILE" ] || echo "Competition is not initialized. Please run the 'init' command first."
}

filter_not_initialized() {
    [ ! -f "$LOCK_FILE" ] || echo "Competition is already initialized. To re-initialize, please run the 'clean' command first."
}

filter_valid_config() {
    local errors
    errors=$(validate_configuration)
    if [ -n "$errors" ]; then
        printf 'Invalid configuration:\n%s\n' "$(sed 's/^/  - /' <<< "$errors")"
    fi
}
