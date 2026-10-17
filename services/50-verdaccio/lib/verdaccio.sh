# shellcheck shell=bash
# Verdaccio service helpers: npm proxy on/off and npm cache (loaded with service_hooks.sh).
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
# <list file> gets the tarball of every installed package, as a path in Verdaccio's storage
# (/react/react-19.1.1.tgz, /@scope/name/name-1.0.0.tgz), read from npm's hidden lockfile: it lists exactly what
# was installed for that platform. npm silently skips optional dependencies it cannot download, so checking
# these files (verify_npm_cache) is the reliable way to know the cache is complete.
npm_install_through_verdaccio() {
    local list_file=$1 platform=$2 project_dir=$3
    local os cpu libc flags
    IFS=- read -r os cpu libc <<< "$platform"
    flags=(--os="$os" --cpu="$cpu")
    [ "$os" = linux ] && flags+=(--libc="${libc:-glibc}")

    docker run --rm --network gitea -v "$project_dir:/project:ro" "$VERDACCIO_NODE_IMAGE" sh -c '
        mkdir /tmp/app && cp /project/package*.json /tmp/app/ && cd /tmp/app &&
        npm install --registry http://verdaccio:4873 --no-audit --no-fund --no-update-notifier --ignore-scripts "$@" >&2 &&
        node -e "
            const lock = require(\"./node_modules/.package-lock.json\");
            for (const p of Object.values(lock.packages || {}))
                if (p.resolved && !p.link) console.log(decodeURIComponent(new URL(p.resolved).pathname).replace(\"/-/\", \"/\"));
        " | sort -u
    ' sh "${flags[@]}" > "$list_file"
}

# verify_npm_cache <list file...>: print the tarballs of the lists that are not in Verdaccio's storage
verify_npm_cache() {
    sort -u "$@" | while read -r tarball; do
        [ -f "$DATA_DIR/verdaccio$tarball" ] || echo "$tarball"
    done
}

# download_npm_dependencies <lists dir> <project...>: every project for every platform, 3 installs at a time.
# Returns 1 if an install failed (its output is in <lists dir>/<name>.<platform>.log).
download_npm_dependencies() {
    local lists=$1
    shift
    local project name platform failed=0 running=0
    for project in "$@"; do
        name=$(echo "${project#*/manifests/}" | tr "/" "_")
        for platform in "${VERDACCIO_PLATFORMS[@]}"; do
            npm_install_through_verdaccio "$lists/$name.$platform.list" "$platform" "$project" \
                2> "$lists/$name.$platform.log" || touch "$lists/$name.$platform.failed" &
            running=$((running + 1))
            if [ $running -ge 3 ]; then
                wait -n
                running=$((running - 1))
            fi
        done
    done
    wait
    for failed_file in "$lists"/*.failed; do
        [ -e "$failed_file" ] || continue
        failed=1
        echo "Install failed: $(basename "$failed_file" .failed)"
        tail -n 5 "${failed_file%.failed}.log"
    done
    return $failed
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

# prefetch_npm_packages [--keep-online]
# Cache the npm dependencies of every framework template for every platform, check that every installed
# package is in the cache, then cut npmjs off. On any failure the npm proxy is left on: a partial cache with
# npmjs cut off would break every install. Returns 1 on failure.
# shellcheck disable=SC2120  # --keep-online is passed by the prefetch-npm command, outside this file
prefetch_npm_packages() {
    local keep_online=false
    [ "${1:-}" = "--keep-online" ] && keep_online=true

    local work projects missing
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
    if [ ${#projects[@]} -gt 0 ]; then
        if ! run_with_spinner "Downloading the dependencies of ${#projects[@]} template(s) for ${#VERDACCIO_PLATFORMS[@]} platform(s)..." \
            download_npm_dependencies "$work/lists" "${projects[@]}"; then
            rm -rf "$work"
            log_error "Download failed, the npm proxy stays on. Run again: sudo ./competition.sh prefetch-npm"
            return 1
        fi

        # Every installed tarball must be in the cache (npm would silently skip a missing optional one)
        missing=$(verify_npm_cache "$work"/lists/*.list)
        if [ -n "$missing" ]; then
            log_error "Some packages are missing from the cache, the npm proxy stays on:"
            sed 's/^/  /' <<< "$missing" >&2
            rm -rf "$work"
            return 1
        fi
        log_success "Template dependencies cached in data/verdaccio ($(sort -u "$work"/lists/*.list | wc -l) packages)"
    fi
    rm -rf "$work"

    if [ "$keep_online" = true ]; then
        log_warning "npm proxy left on: competitors can install any npm package"
        return 0
    fi

    write_verdaccio_config off
    restart_verdaccio
    log_success "npmjs is cut off: only the templates' dependencies can be installed"
}
