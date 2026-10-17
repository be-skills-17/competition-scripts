# shellcheck shell=bash
# Dashboard: static page served by nginx on 127.0.0.1:8090 (see compose.yaml)

# Before every "up" (init, restore, recreate): the file must exist, or Docker would mount an empty directory
service_dashboard_pre_up() {
    write_dashboard_config
}
