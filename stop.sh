#!/bin/bash

docker compose -f ./docker/gitea-runner.yaml stop 
GITEA_HOSTNAME=$DOMAIN docker compose -f ./docker/gitea.yaml stop 
docker compose -f ./docker/traefik.yaml stop 
docker compose -f ./docker/watchtower.yaml stop
docker compose -f ./docker/verdaccio.yaml stop
