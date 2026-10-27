# shellcheck shell=bash
# Portainer: Docker management UI on 127.0.0.1:9443 (see compose.yaml)

# Before every "up" (init, restore, recreate): the file must exist, or Docker would mount an empty directory.
# Portainer only reads it when no admin exists yet (first start): changing the password later is done in its UI.
service_portainer_pre_up() {
    local dir
    dir=$(service_dynamic_dir portainer)
    mkdir -p "$dir" || return 1
    (umask 077 && printf '%s' "$PASSWORD" > "$dir/admin_password") || return 1
}
