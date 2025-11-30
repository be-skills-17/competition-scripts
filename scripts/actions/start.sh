#!/bin/bash

docker compose -f $DOCKER_DIR/traefik.yaml start
docker compose -f $DOCKER_DIR/gitea.yaml start
docker compose -f $DOCKER_DIR/gitea-runner.yaml start
docker compose -f $DOCKER_DIR/mysql.yaml start
docker compose -f $DOCKER_DIR/verdaccio.yaml start

