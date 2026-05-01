#!/bin/bash

docker compose -f $DOCKER_DIR/traefik.yaml start
docker compose -f $DOCKER_DIR/gitea.yaml start
docker compose -f $DOCKER_DIR/gitea-runner.yaml start
docker compose -f $DOCKER_DIR/mysql.yaml start
docker compose -f $DOCKER_DIR/verdaccio.yaml start
docker compose -f $DOCKER_DIR/wud.yaml start
docker compose -f $DYNAMIC_DOCKER_DIR/competitors.yaml start


