# Services

Each service is a directory `services/<NN>-<name>/`:

```
services/
  10-traefik/      compose.yaml
  20-gitea/        compose.yaml  service.sh   # wait_ready, post_init (admin, tokens, orgs, frameworks)
  30-runners/      compose.yaml
  40-mysql/        compose.yaml  service.sh   # pre_init (competitors.sql)
  50-verdaccio/    compose.yaml  service.sh   # pre_init (permissions, config), wait_ready, post_init (prefetch npm)
  60-wud/          compose.yaml
  70-competitors/                service.sh   # compose_file (generated), pre_init (users, images), clean (images)
  75-apis/                       service.sh   # compose_file (generated), pre_init (SQLite copies), clean
                                 start-apache.sh
```

- `NN` is the start order; `stop`, `clean` go in reverse order. `<name>` is the name used by
  `recreate` and in hook names.
- `compose.yaml` is the service's compose file.
- `service.sh` is optional and defines hooks named `service_<name>_<hook>` (dashes in `<name>` become
  underscores). Every hook is optional:

| Hook | Called by | When |
|---|---|---|
| `compose_file` | every command | prints the compose file path, if it is not the service's `compose.yaml` |
| `pre_init` | `init` | before the first `docker compose up` (generate files, prepare data directories) |
| `wait_ready` | `init`, `restore` | after `docker compose up`, returns once the service answers |
| `post_init` | `init` | once the service is ready (create users, import data...) |
| `clean` | `clean`, `restore` | after the containers are removed, before `data/` is deleted |

`init` runs, for each service in order: `pre_init`, `up -d`, `wait_ready`, `post_init`. A service can use what
an earlier one prepared: the runners use the registration token created by gitea's `post_init`.

**Adding a service:** create `services/<NN>-<name>/compose.yaml` (and `service.sh` if it needs hooks). Every
command picks it up, without regenerating `competition.sh`.
