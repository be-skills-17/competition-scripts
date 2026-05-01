#!/bin/bash

# Source logging
source "$SCRIPTS_DIR/logging.sh"

# Source configuration utilities
source "$SCRIPTS_DIR/config.sh"

# Load configuration from main.json
load_configuration

log_section "Cleaning Competition Environment"

log_subsection "Stopping Docker Services"
docker compose -f $DOCKER_DIR/wud.yaml down
docker compose -f $DYNAMIC_DOCKER_DIR/competitors.yaml down || true
docker compose -f $DOCKER_DIR/mysql.yaml down
docker compose -f $DOCKER_DIR/verdaccio.yaml down
docker compose -f $DOCKER_DIR/gitea-runner.yaml down
docker compose -f $DOCKER_DIR/gitea.yaml down 
docker compose -f $DOCKER_DIR/traefik.yaml down
log_success "Docker services stopped"

# Delete all volumes from the containers
log_subsection "Removing Data Volumes"
rm -rf $DATA_DIR
log_success "Data volumes removed"

# Remove Docker images for all competitors
log_subsection "Removing Competitor Images"
for row in $(jq -r '.competitors[] | @base64' "$CONFIG_FILE"); do
  _jq() {
    echo ${row} | base64 --decode | jq -r ${1}
  }
  
  username=$(_jq '.username')
  log_info "Removing images for competitor: $username"
  docker images -q --filter "reference=$username*" | xargs -r docker rmi -f
done
log_success "Competitor images removed"

# Clean up dynamic directories
log_subsection "Cleaning up Dynamic Directories"
rm -rf $DYNAMIC_DOCKER_DIR
rm -rf $DYNAMIC_FRAMEWORKS_DIR
rm -f $LOCK_FILE
log_success "Dynamic directories cleaned"

echo ""
log_success "Clean complete! Environment reset. 🧹"
