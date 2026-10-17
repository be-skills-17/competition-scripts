# shellcheck shell=bash
# WUD: deploys the competitors' new images from Gitea's registry (helpers: lib/wud.sh)

# Before every "up" (init, restore, recreate): registry.env must exist (env_file of compose.yaml). Gitea is
# started before WUD (20 < 60), so its token can be checked or created here.
service_wud_pre_up() {
    write_wud_registry_env
}
