#!/bin/bash

# Source logging
source "$SCRIPTS_DIR/logging.sh"

# Source configuration utilities
source "$SCRIPTS_DIR/config.sh"
source "$SCRIPTS_DIR/backup.sh"

DO_BACKUP=true
for arg in "$@"; do
  case $arg in
    --no-backup) DO_BACKUP=false ;;
    *) log_error "Unknown option for clean: $arg"; exit 1 ;;
  esac
done

# Load configuration from main.json
load_configuration
CONFIG_FILE=$CONFIG_DIR/main.json

log_section "Cleaning Competition Environment"

log_subsection "Stopping Docker Services"
docker compose -f $DOCKER_DIR/wud.yaml down -v
docker compose -f $DYNAMIC_DOCKER_DIR/competitors.yaml down -v || true
docker compose -f $DOCKER_DIR/mysql.yaml down -v
docker compose -f $DOCKER_DIR/verdaccio.yaml down -v
docker compose -f $DOCKER_DIR/gitea-runner.yaml down -v
docker compose -f $DOCKER_DIR/gitea.yaml down -v 
docker compose -f $DOCKER_DIR/traefik.yaml down -v
log_success "Docker services stopped"

# Services are down at this point, so the copy is consistent
if [ "$DO_BACKUP" = true ]; then
  log_subsection "Backing up before removing anything"
  if ! create_backup_archive "clean"; then
    log_error "Backup failed, nothing was deleted. Use --no-backup to clean anyway."
    exit 1
  fi
else
  log_warning "Skipping backup (--no-backup)"
fi

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
  docker images -q --filter "reference=git.$DOMAIN/$username/*" | xargs -r docker rmi -f
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
