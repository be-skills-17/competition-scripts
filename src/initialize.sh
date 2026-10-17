# Runs before argument parsing, for every command (including --help)

# Everything is relative to the script location, never to the current directory
BASE_DIR=$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)

# Values computed by init (domain, credentials, tokens...) and the paths
load_env_file

export COMPOSE_PROJECT_NAME="competition_scripts"
export COMPOSE_IGNORE_ORPHANS=true

export VERBOSE=false
export REDIRECT=/dev/null

# Service hooks (see src/lib/services.sh), loaded at runtime: adding a service needs no regeneration
for service_file in "$SERVICES_DIR"/*/service.sh; do
    # shellcheck disable=SC1090
    [ -f "$service_file" ] && source "$service_file"
done
