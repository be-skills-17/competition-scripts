#!/bin/bash

docker compose -f $DOCKER_DIR/traefik.yaml stop
docker compose -f $DOCKER_DIR/gitea.yaml stop
docker compose -f $DOCKER_DIR/gitea-runner.yaml stop
docker compose -f $DOCKER_DIR/mysql.yaml stop
docker compose -f $DOCKER_DIR/verdaccio.yaml stop
docker compose -f $DOCKER_DIR/wud.yaml stop
docker compose -f $DYNAMIC_DOCKER_DIR/competitors.yaml stop