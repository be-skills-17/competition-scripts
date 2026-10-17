# shellcheck shell=bash
# Verdaccio: private npm registry.
# config/verdaccio/config.yaml is generated from config.template.yaml, in one of two modes:
#   on   packages are fetched from npmjs and cached in data/verdaccio (the template as is)
#   off  the "uplinks" and "middlewares" sections and every "proxy:" line are removed: only packages already
#        cached in data/verdaccio can be installed. Removing "proxy:" alone is NOT enough: Verdaccio 6 still
#        queries the declared uplinks for packages without "proxy".
# By default npm is off: init (post_init) caches the dependencies of every framework template in Gitea
# (their package.json and package-lock.json), then cuts npmjs off.

VERDACCIO_NODE_IMAGE="node:22.20.0-alpine"
# Platforms whose native binaries (esbuild, rollup...) are cached: competition PCs and glibc images (linux-x64),
# alpine images such as the vuejs template's Dockerfile (linux-x64-musl), Windows (win32-x64)
VERDACCIO_PLATFORMS=(linux-x64 linux-x64-musl win32-x64)

# Write config/verdaccio/config.yaml with the npm proxy "on" or "off"
write_verdaccio_config() {
    local mode=$1
    local template="$CONFIG_DIR/verdaccio/config.template.yaml"
    local file="$CONFIG_DIR/verdaccio/config.yaml"

    {
        echo "# Generated from config.template.yaml by competition.sh (npm proxy: $mode), do not edit"
        if [ "$mode" = on ]; then
            cat "$template"
        else
            # Skip the top-level "uplinks:" and "middlewares:" blocks (until the next top-level key)
            awk '
                /^(uplinks|middlewares):/ { skip = 1; next }
                skip && /^[^[:space:]#]/ { skip = 0 }
                skip || /^[[:space:]]*proxy:/ { next }
                { print }
            ' "$template"
        fi
    } > "$file"
}

# Print "on" or "off"
verdaccio_proxy_mode() {
    grep -q '^uplinks:' "$CONFIG_DIR/verdaccio/config.yaml" 2> /dev/null && echo on || echo off
}

poll_verdaccio() {
    local count=0
    until curl -s -o /dev/null http://localhost:4873/-/ping; do
        [ $count -ge 30 ] && return 1
        sleep 2
        count=$((count + 1))
    done
}

wait_for_verdaccio() {
    if ! run_with_spinner "Waiting for Verdaccio to be ready..." poll_verdaccio; then
        log_error "Verdaccio did not become ready in time."
        exit 1
    fi
}

# Verdaccio reads its config at startup only
restart_verdaccio() {
    docker compose -f "$(service_compose_file verdaccio)" restart > "$REDIRECT" 2>&1
    wait_for_verdaccio
}

# npm_install_through_verdaccio <list file> <platform> <project dir>
# Run "npm install" on the project's package.json (and package-lock.json: same versions as the template's
# builds) in a throwaway node container, through Verdaccio, for a platform such as linux-x64, linux-x64-musl
# or win32-x64: npm downloads the native optional dependencies of that platform (esbuild, rollup...). The
# container starts with an empty npm cache, so everything goes through Verdaccio.
# The sorted list of installed packages is written to <list file>: npm silently skips optional dependencies
# it cannot download, so comparing lists (online vs offline) is the only reliable check.
npm_install_through_verdaccio() {
    local list_file=$1 platform=$2 project_dir=$3
    local os cpu libc flags
    IFS=- read -r os cpu libc <<< "$platform"
    flags=(--os="$os" --cpu="$cpu")
    [ "$os" = linux ] && flags+=(--libc="${libc:-glibc}")

    docker run --rm --network gitea -v "$project_dir:/project:ro" "$VERDACCIO_NODE_IMAGE" sh -c '
        mkdir /tmp/app && cp /project/package*.json /tmp/app/ && cd /tmp/app &&
        npm install --registry http://verdaccio:4873 --no-audit --no-fund --no-update-notifier --ignore-scripts "$@" >&2 &&
        npm ls --all --parseable 2> /dev/null | sort
    ' sh "${flags[@]}" > "$list_file"
}

# Download the package.json (and package-lock.json) of every framework template in Gitea into <dest dir>,
# one folder per package.json, and print the folders
fetch_framework_manifests() {
    local dest=$1
    local auth=(-sk -u "$USERNAME:$PASSWORD")
    local api="$GITEA_URL/api/v1/repos/frameworks"
    local repo path dir

    for repo in $(curl "${auth[@]}" "$GITEA_URL/api/v1/orgs/frameworks/repos?limit=100" | jq -r '.[].name'); do
        while read -r path; do
            [ -n "$path" ] || continue
            dir="$dest/$repo"
            [ "$(dirname "$path")" = . ] || dir="$dir/$(dirname "$path")"
            mkdir -p "$dir"
            curl "${auth[@]}" -o "$dir/package.json" "$api/$repo/raw/$path"
            curl "${auth[@]}" -f -o "$dir/package-lock.json" "$api/$repo/raw/${path%package.json}package-lock.json" \
                || rm -f "$dir/package-lock.json"
            echo "$dir"
        done < <(curl "${auth[@]}" "$api/$repo/git/trees/main?recursive=true&per_page=10000" \
            | jq -r '.tree[]? | select(.type == "blob" and (.path | test("(^|/)package\\.json$"))
                and (.path | test("node_modules") | not)) | .path')
    done
}

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

# prefetch_npm_packages [--keep-online]
# Cache the npm dependencies of every framework template for every platform, then cut npmjs off and check
# that the same packages install offline. On any failure the npm proxy is left on: a partial cache with npmjs
# cut off would break every install. Returns 1 on failure.
# shellcheck disable=SC2120  # --keep-online is passed by the prefetch-npm command, outside this file
prefetch_npm_packages() {
    local keep_online=false
    [ "${1:-}" = "--keep-online" ] && keep_online=true

    local work projects project name platform
    work=$(mktemp -d)
    mapfile -t projects < <(fetch_framework_manifests "$work/manifests")
    mkdir -p "$work/lists"

    if [ ${#projects[@]} -eq 0 ]; then
        log_warning "No package.json in the framework templates: nothing to cache"
    else
        log_info "Templates: $(printf '%s\n' "${projects[@]#"$work/manifests/"}" | tr '\n' ' ')"
    fi
    log_info "Platforms: ${VERDACCIO_PLATFORMS[*]}"

    write_verdaccio_config on
    restart_verdaccio
    for project in "${projects[@]}"; do
        name=$(echo "${project#"$work/manifests/"}" | tr '/' '_')
        for platform in "${VERDACCIO_PLATFORMS[@]}"; do
            if ! run_with_spinner "Downloading $name for $platform..." \
                npm_install_through_verdaccio "$work/lists/$name.$platform.online" "$platform" "$project"; then
                rm -rf "$work"
                log_error "Download failed, the npm proxy stays on. Run again: sudo ./competition.sh prefetch-npm"
                return 1
            fi
        done
    done
    [ ${#projects[@]} -gt 0 ] && log_success "Template dependencies cached in data/verdaccio"

    if [ "$keep_online" = true ]; then
        rm -rf "$work"
        log_warning "npm proxy left on: competitors can install any npm package"
        return 0
    fi

    write_verdaccio_config off
    restart_verdaccio

    # Same installs without npmjs must give exactly the same packages (npm silently skips missing optional ones)
    for project in "${projects[@]}"; do
        name=$(echo "${project#"$work/manifests/"}" | tr '/' '_')
        for platform in "${VERDACCIO_PLATFORMS[@]}"; do
            if ! run_with_spinner "Checking the offline install of $name for $platform..." \
                npm_install_through_verdaccio "$work/lists/$name.$platform.offline" "$platform" "$project" \
                || ! diff -q "$work/lists/$name.$platform.online" "$work/lists/$name.$platform.offline" > /dev/null; then
                log_error "Some packages of $name for $platform are missing from the cache:"
                diff "$work/lists/$name.$platform.online" "$work/lists/$name.$platform.offline" \
                    | grep '^<' | sed 's#.*/node_modules/#  #' >&2
                rm -rf "$work"
                write_verdaccio_config on
                restart_verdaccio
                log_error "The npm proxy was turned back on. Run again: sudo ./competition.sh prefetch-npm"
                return 1
            fi
        done
    done
    rm -rf "$work"
    log_success "npmjs is cut off: only the templates' dependencies can be installed"
}

# npm is cut off by default: the packages of config/main.json are cached, then npmjs is cut off.
# A failure does not stop init (the proxy stays on and the error says what to do).
service_verdaccio_post_init() {
    log_subsection "npm packages"
    prefetch_npm_packages || true
}
