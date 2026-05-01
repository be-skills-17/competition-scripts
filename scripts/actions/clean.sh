#!/bin/bash

# Source configuration utilities
source "$SCRIPTS_DIR/config.sh"

# Load configuration from main.json
load_configuration

echo "Cleaning Docker services..."
echo $DOCKER_DIR

docker compose -f $DOCKER_DIR/wud.yaml down
docker compose -f $DYNAMIC_DOCKER_DIR/competitors.yaml down || true
docker compose -f $DOCKER_DIR/mysql.yaml down
docker compose -f $DOCKER_DIR/verdaccio.yaml down
docker compose -f $DOCKER_DIR/gitea-runner.yaml down
docker compose -f $DOCKER_DIR/gitea.yaml down 
docker compose -f $DOCKER_DIR/traefik.yaml down

# Delete all volumes from the containers
echo "Removing data volumes..."
rm -rf $DATA_DIR

# Remove Docker images for all competitors
echo "Removing competitor images..."
for row in $(jq -r '.competitors[] | @base64' "$CONFIG_FILE"); do
  _jq() {
    echo ${row} | base64 --decode | jq -r ${1}
  }
  
  username=$(_jq '.username')
  echo "Removing images for competitor: $username"
  docker images -q --filter "reference=$username*" | xargs -r docker rmi -f
done

# Clean up dynamic directories
echo "Cleaning up dynamic directories..."
rm -rf $DYNAMIC_DOCKER_DIR
rm -rf $DYNAMIC_FRAMEWORKS_DIR
rm -f $LOCK_FILE

echo "Clean complete!"
