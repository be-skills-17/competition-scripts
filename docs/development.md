# Development

`competition.sh` is generated with [bashly](https://bashly.dev) from the sources in `src/`. **Do not edit
`competition.sh` directly**, edit `src/` and regenerate it. The services in `services/` are loaded at runtime
and need no regeneration.

```
bashly-settings.yml        # bashly settings (source dir, production mode)
services/                  # one directory per service, see services.md
tests/                     # run.sh (all checks), *.bats tests, fixtures/, Dockerfile of the test runner
src/
  bashly.yml               # commands, arguments, flags, filters, dependencies and help texts
  initialize.sh            # runs first: loads .env and defines paths
  before.sh                # runs after argument parsing: --verbose
  <command>_command.sh     # one file per command (init, start, recreate, backup...)
  lib/                     # functions shared by the commands
    services.sh            # service discovery, hooks and compose helpers
    filters.sh             # root / initialized checks used by the commands' filters
    logging.sh, config.sh, gitea.sh, frameworks.sh, competitors.sh, backup.sh, clean.sh, recreate.sh...
```

Regenerate `competition.sh` after any change (only Docker is needed, no Ruby):

```bash
docker run --rm --user $(id -u):$(id -g) -v "$PWD:/app" dannyben/bashly:2.0.0 generate
```

Commit both `src/` and the generated `competition.sh`, so users never need bashly.

## Tests

```bash
tests/run.sh                      # everything
tests/run.sh tests/config.bats    # a single test file
```

`tests/run.sh` only needs Docker. It checks that:
1. `competition.sh` is up to date with `src/` (regenerated in a temporary directory and compared);
2. `competition.sh`, the `service.sh` files and `tests/run.sh` pass [shellcheck](https://www.shellcheck.net);
3. the [bats](https://bats-core.readthedocs.io) tests in `tests/*.bats` pass. They cover the logic that needs
   neither Docker nor Gitea: config validation, service discovery and hooks, backups, `.env` loading, generated
   files (compose, SQL), filters and the spinner. Each test runs in a temporary project directory built from
   `tests/fixtures/main.json`; the real `config/`, `data/` and containers are never touched.

- Adding a command: declare it in `src/bashly.yml`, run the generate command above; bashly creates
  `src/<command>_command.sh` for you to fill.
