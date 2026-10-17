# shellcheck shell=bash
# WUD service helpers: Gitea registry credentials (loaded with service_hooks.sh)

# WUD checks every competitor image in Gitea's registry every 10 seconds, and asks a registry token for each
# request. With the admin password, Gitea verifies it with its (deliberately slow) password hash every time:
# about 60 ms of CPU each, 150 times per check with 30 containers. A personal access token is much cheaper.
# The token (read:package only) is written to dynamic/wud/registry.env, read by compose (env_file).

wud_registry_env_file() {
    echo "$(service_dynamic_dir wud)/registry.env"
}

# Returns 0 if Gitea's registry accepts the admin login with <secret> (a token or the password)
wud_registry_login_is_valid() {
    [ -n "$1" ] || return 1
    [ "$(curl -s -k -o /dev/null -w '%{http_code}' -u "$USERNAME:$1" \
        "$GITEA_URL/v2/token?service=container_registry")" = "200" ]
}

# Keep the token of registry.env while Gitea accepts it, otherwise create a new one. If Gitea does not answer,
# an existing file is kept as is, and without one WUD falls back to the admin password (slower, but working).
write_wud_registry_env() {
    local file token
    file=$(wud_registry_env_file)
    mkdir -p "$(dirname "$file")"

    token=
    [ -f "$file" ] && token=$(sed -n 's/^WUD_REGISTRY_GITEA_PRIVATE_PASSWORD=//p' "$file")
    if [ -n "$token" ] && [ "$token" != "$PASSWORD" ] && wud_registry_login_is_valid "$token"; then
        return 0
    fi

    if token=$(create_pat "wud-registry-$(date +%Y%m%d%H%M%S)" '["read:package"]') \
        && wud_registry_login_is_valid "$token"; then
        log_info "WUD reads Gitea's registry with a read:package token"
    elif [ -f "$file" ]; then
        log_warning "Could not create a Gitea token for WUD, keeping $file"
        return 0
    else
        log_warning "Could not create a Gitea token for WUD, using the admin password (more CPU in Gitea)"
        token=$PASSWORD
    fi
    (umask 077 && echo "WUD_REGISTRY_GITEA_PRIVATE_PASSWORD=$token" > "$file")
}
