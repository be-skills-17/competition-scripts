# Shared setup: a temporary project directory with the library functions loaded.
# Docker, Gitea and the network are never used: the tests only cover the pure logic.

REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup_project() {
    BASE_DIR="$BATS_TEST_TMPDIR/project"
    mkdir -p "$BASE_DIR/config/mysql" "$BASE_DIR/services"
    cp "$REPO_DIR/tests/fixtures/main.json" "$BASE_DIR/config/main.json"

    local lib
    for lib in "$REPO_DIR"/src/lib/*.sh "$REPO_DIR"/services/*/lib/*.sh; do
        # shellcheck disable=SC1090
        source "$lib"
    done
    set_paths
    VERBOSE=false
    REDIRECT=/dev/null
    CONFIG_FILE=$CONFIG_DIR/main.json
}

# Apply a jq filter to the project's main.json
edit_config() {
    local tmp
    tmp=$(mktemp)
    jq "$@" "$CONFIG_DIR/main.json" > "$tmp" && mv "$tmp" "$CONFIG_DIR/main.json"
}

# Create services/<dir>/compose.yaml (and service_hooks.sh from stdin when --hooks is given)
add_service() {
    local dir=$1
    mkdir -p "$SERVICES_DIR/$dir"
    touch "$SERVICES_DIR/$dir/compose.yaml"
    if [ "$2" = "--hooks" ]; then
        cat > "$SERVICES_DIR/$dir/service_hooks.sh"
        # shellcheck disable=SC1091
        source "$SERVICES_DIR/$dir/service_hooks.sh"
    fi
}
