# Services

Each service is a directory `services/<NN>-<name>/`:

```
services/
  10-traefik/      compose.yaml
  20-gitea/        compose.yaml  service_hooks.sh  lib/   # wait_ready, post_init (admin, tokens, orgs, frameworks)
  30-runners/      compose.yaml
  40-mysql/        compose.yaml  service_hooks.sh  lib/   # pre_init (competitors.sql)
  50-verdaccio/    compose.yaml  service_hooks.sh  lib/   # pre_init (permissions, config), wait_ready, post_init (prefetch npm)
  60-wud/          compose.yaml
  65-glances/      compose.yaml                           # server metrics API, used by the dashboard
  70-competitors/                service_hooks.sh  lib/   # compose_file (generated), pre_init (users, images), clean (images)
  75-apis/                       service_hooks.sh  lib/   # compose_file (generated), pre_init (SQLite copies), clean
                                 start-apache.sh
  80-dashboard/    compose.yaml  service_hooks.sh  lib/   # pre_up (config.js), nginx.conf, html/
  85-portal/       compose.yaml  service_hooks.sh  lib/   # pre_up (portal.json), public/ (competitor portal, PHP)
```

- `NN` is the start order; `stop`, `clean` go in reverse order. `<name>` is the name used by
  `recreate` and in hook names.
- `compose.yaml` is the service's compose file.
- Files generated for the service (a generated compose file, configs mounted in containers...) go to
  `dynamic/<name>/` (`service_dynamic_dir <name>`, `${DYNAMIC_DIR}/<name>/` in a compose file). The core backs up
  and cleans `dynamic/` as a whole: a service never needs changes in `src/`.
- `service_hooks.sh` (optional) holds **only** the hooks, functions named `service_<name>_<hook>` (dashes in
  `<name>` become underscores). Every hook is optional (see the table below).
- `lib/*.sh` (optional) holds everything else: the service's helper functions and constants, used by its hooks
  and by its own commands (`deploy-apis` uses `services/75-apis/lib/apis.sh`, `npm-proxy`
  `services/50-verdaccio/lib/verdaccio.sh`). Loaded with `service_hooks.sh`, at runtime.

Hooks:

| Hook | Called by | When |
|---|---|---|
| `validate` | `check-config`, `init`, `import-frameworks`, `deploy-apis`... | prints one line per problem in the service's own configuration (e.g. `api.json` files) |
| `compose_file` | every command | prints the compose file path, if it is not the service's `compose.yaml` |
| `pre_init` | `init` | before the first `docker compose up` (generate files, prepare data directories) |
| `pre_up` | `init`, `restore`, `recreate`, `deploy-apis` | before every `docker compose up` (files the containers mount); also when something they may show changed (`deploy-apis`). Must be safe to run again at any time |
| `wait_ready` | `init`, `restore` | after `docker compose up`, returns once the service answers |
| `post_init` | `init` | once the service is ready (create users, import data...) |
| `recreate_override` | `recreate` | prints compose YAML merged over the service's compose file for the container being recreated (the competitors keep the image deployed by WUD) |
| `clean` | `clean`, `restore` | after the containers are removed, before `data/` is deleted |

`init` runs, for each service in order: `pre_init`, `pre_up`, `up -d`, `wait_ready`, `post_init`. A service can use what
an earlier one prepared: the runners use the registration token created by gitea's `post_init`.

**Adding a service:** create `services/<NN>-<name>/compose.yaml` (and `service_hooks.sh` if it needs hooks, `lib/<name>.sh` for its helpers). Every
command picks it up, without regenerating `competition.sh`.
