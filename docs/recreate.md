# Recreating a single service

`sudo ./competition.sh recreate <service|group> ...` runs `docker compose up -d --no-deps --force-recreate` on the
given services only. Run it without arguments to list the available names. A group (`traefik`, `gitea`,
`runners`, `mysql`, `verdaccio`, `wud`, `competitors`) recreates every container of that service; an exact
service name always wins (`gitea` only recreates the Gitea container, not `gitea-db`).

What survives a recreate:

| Service | Persistent data | Lost on recreate |
|---|---|---|
| traefik | `config/traefik`, `config/letsencrypt` | nothing |
| gitea | `data/gitea` (repos, container registry, avatars, sessions), `config/gitea` | nothing |
| gitea-db | `data/mysql-gitea` | nothing |
| runner1..6 | `data/runnerN/.runner` (registration) | jobs running at that moment |
| competitor_db | `data/mysql-competition` | nothing (`competitors.sql` only runs on an empty data dir) |
| phpmyadmin | - | login sessions |
| verdaccio | `data/verdaccio` (packages), `config/verdaccio` | nothing |
| whatsupdocker | - | update history; it rescans within seconds |
| competitor containers | - | anything written inside the container; the image currently deployed by WUD is kept |
