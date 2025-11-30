#!/bin/bash

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1090
  source .env
  set +a
fi

docker compose -f $DOCKER_DIR/gitea-runner.yaml stop 
GITEA_HOSTNAME=$DOMAIN docker compose -f $DOCKER_DIR/gitea.yaml stop 
docker compose -f $DOCKER_DIR/traefik.yaml stop 
docker compose -f $DOCKER_DIR/watchtower.yaml stop
docker compose -f $DOCKER_DIR/verdaccio.yaml stop