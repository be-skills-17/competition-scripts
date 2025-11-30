#!/bin/bash

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1090
  source .env
  set +a
fi

DOMAIN=$(sed -n '1p' $CONFIG_DIR/main)
docker compose -f $DOCKER_DIR/watchtower.yaml down
docker compose -f $DOCKER_DIR/competitors.yaml down
docker compose -f $DOCKER_DIR/mysql.yaml down
docker compose -f $DOCKER_DIR/gitea-runner.yaml down
GITEA_HOSTNAME=$DOMAIN docker compose -f $DOCKER_DIR/gitea.yaml down 
docker compose -f $DOCKER_DIR/traefik.yaml down

# delete all volumes from the containers
rm -rf $DATA_DIR

# go through all competitors and remove all images
tail -n +5 config/main | while read -r user pass sub; do
  echo $user
  docker images | grep $user | awk '{print $3}' | xargs docker rmi -f
done

rm -rf $DYNAMIC_DOCKER_DIR
rm -rf $DYNAMIC_FRAMEWORKS_DIR
rm -f $LOCK_FILE