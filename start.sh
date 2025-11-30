#!/bin/bash

docker compose -f ./docker/traefik.yaml start
docker compose -f ./docker/gitea.yaml start
docker compose -f ./docker/gitea-runner.yaml start
docker compose -f ./docker/mysql.yaml start
docker compose -f ./docker/verdaccio.yaml start

