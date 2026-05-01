#!/bin/bash

echo $DOCKER_DIR
docker compose -f $DOCKER_DIR/wud.yaml down
docker compose -f $DYNAMIC_DOCKER_DIR/competitors.yaml down || true
docker compose -f $DOCKER_DIR/mysql.yaml down
docker compose -f $DOCKER_DIR/verdaccio.yaml down
docker compose -f $DOCKER_DIR/gitea-runner.yaml down
docker compose -f $DOCKER_DIR/gitea.yaml down 
docker compose -f $DOCKER_DIR/traefik.yaml down

# delete all volumes from the containers
rm -rf $DATA_DIR

# go through all competitors and remove all images
tail -n +5 config/main | while read -r user pass sub; do
  echo $user
  docker images -q --filter "reference=$user*" | xargs -r docker rmi -f
done

rm -rf $DYNAMIC_DOCKER_DIR
rm -rf $DYNAMIC_FRAMEWORKS_DIR
rm -f $LOCK_FILE
