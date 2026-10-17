# shellcheck shell=bash
# Portal: competitor dashboard on the main domain (see compose.yaml and public/index.php)

# Before every "up" (init, restore, recreate): the file must exist, and APIs may have changed
service_portal_pre_up() {
    write_portal_config
}
