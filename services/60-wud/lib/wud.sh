# shellcheck shell=bash
# WUD service helpers: Gitea registry credentials (loaded with service_hooks.sh)

# WUD checks every competitor image in Gitea's registry every 10 seconds. Each registry token request makes
# Gitea verify the login: with the admin password, its (deliberately slow) password hash, about 60 ms of CPU.
# So WUD logs in with a personal access token (read:package only, much cheaper), written to
# dynamic/wud/registry.env and read by compose (env_file); and the registry is a "custom" one in compose.yaml,
# whose tokens are cached (WUD's "gitea" provider asks one for every request).

WUD_REGISTRY_PASSWORD_VARIABLE=WUD_REGISTRY_CUSTOM_GITEA_PASSWORD

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
# the existing token is kept, and without one WUD falls back to the admin password (slower, but working).
# The file is always written again: a token saved under the variable name used before the "custom" registry
# (WUD_REGISTRY_GITEA_PRIVATE_PASSWORD) moves to the current one.
write_wud_registry_env() {
    local file existing='' token
    file=$(wud_registry_env_file)
    mkdir -p "$(dirname "$file")"
    [ -f "$file" ] && existing=$(sed -nE 's/^WUD_REGISTRY_(CUSTOM_GITEA|GITEA_PRIVATE)_PASSWORD=//p' "$file" | head -n 1)

    if [ -n "$existing" ] && [ "$existing" != "$PASSWORD" ] && wud_registry_login_is_valid "$existing"; then
        token=$existing
    elif token=$(create_pat "wud-registry-$(date +%Y%m%d%H%M%S)" '["read:package"]') \
        && wud_registry_login_is_valid "$token"; then
        log_info "WUD reads Gitea's registry with a read:package token"
    elif [ -n "$existing" ]; then
        log_warning "Could not create a Gitea token for WUD, keeping the one of $file"
        token=$existing
    else
        log_warning "Could not create a Gitea token for WUD, using the admin password (more CPU in Gitea)"
        token=$PASSWORD
    fi
    (umask 077 && echo "$WUD_REGISTRY_PASSWORD_VARIABLE=$token" > "$file")
}
