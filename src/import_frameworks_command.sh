# Reads frameworks_repo and allowed_frameworks from config/main.json:
#   - existing templates get a new "Update framework" commit (history and links from generated repos kept)
#   - newly allowed frameworks are created
#   - frameworks removed from allowed_frameworks are left untouched in Gitea
load_configuration
setup_protocol_vars
setup_service_vars
setup_directory_vars

wait_for_gitea

load_personal_access_token "$BASE_DIR/.env" || exit 1

import_all_frameworks
