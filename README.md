# Competition Environment Setup

## Description
This project provides a simple, reliable, and efficient environment for web development competitions. Using Docker along with Gitea, Traefik, WUD, Verdaccio, and MySQL, it allows organizers to set up a consistent competition environment with minimal effort. Competitors can focus on their work without worrying about complex configurations.

The environment includes:
1. **Docker**: Ensures consistent setups across systems.
2. **Traefik**: Routes requests to the right services with SSL support.
3. **Gitea**: A self-hosted Git server for version control and CI/CD.
4. **Verdaccio**: Private NPM registry for package management.
5. **WUD**: Automatic Docker image updates for competitors.
6. **MySQL**: Manages competition data and per-competitor databases.

## Setting up the Environment

### Quick Start

Get your system ready with a single command:

```bash
# Install all dependencies (Docker, jq, git, curl, etc.)
sudo ./competition.sh setup

# Configure your competition in config/main.json
# Then initialize the environment
sudo ./competition.sh init
```

### Prerequisites

The `setup` action automatically installs all required dependencies:
- **Docker** & **Docker Compose**
- **jq** - for JSON parsing
- **git** - for repository management
- **curl** - for API calls
- **wget** - for downloads
- **certbot** - for SSL certificates

If you prefer to install dependencies manually, see [Manual Installation](#manual-installation).

### Commands

All commands use the main `./competition.sh` script with actions. It must always be run with `sudo`
(data files belong to container users such as MySQL's uid 999, only root can create, back up and restore them):

```bash
# Install all dependencies (requires sudo, run once)
sudo ./competition.sh setup

# Check config/main.json without changing anything
sudo ./competition.sh check-config

# Initialize the environment (generates configs, starts services)
sudo ./competition.sh init

# Start all services
sudo ./competition.sh start

# Stop all services
sudo ./competition.sh stop

# Recreate one or more services without touching the rest of the stack
sudo ./competition.sh recreate gitea
sudo ./competition.sh recreate verdaccio wud
sudo ./competition.sh recreate comp01_module-a

# Re-import the frameworks templates (after changing allowed_frameworks or the frameworks repository)
sudo ./competition.sh import-frameworks

# Back up the whole environment into backups/
sudo ./competition.sh backup

# Restore a backup (a file, a name from backups/, or "latest")
sudo ./competition.sh restore latest

# Clean the entire system (removes volumes, images, configs); a backup is made first
sudo ./competition.sh clean
sudo ./competition.sh clean --no-backup
```

### Re-importing frameworks

`import-frameworks` clones `frameworks_repo` again and imports the frameworks listed in `allowed_frameworks`
(both read from `config/main.json`), without touching anything else:

- A template that already exists in the `frameworks` organization gets a new "Update framework" commit (nothing is
  done if its content did not change). It is never deleted or force-pushed, so repositories competitors created from
  it are not affected and keep their "generated from" link.
- A framework newly added to `allowed_frameworks` is created as a new template.
- A framework removed from `allowed_frameworks` stays in Gitea; delete it from the web UI if needed.

### Provided APIs (native PHP)

Organizers can provide APIs written in native PHP. Each enabled API runs **once per competitor**, in its own
container (`php:<version>-apache`), with its own copy of the SQLite database, at a host name built from the
competitor's subdomain.

APIs are folders in `config/apis/`, which is **not versioned** (except the template). To add one:

```bash
cp -r config/apis/template config/apis/products-api
# write the API in config/apis/products-api/public/, then edit config/apis/products-api/api.json
sudo ./competition.sh check-config
sudo ./competition.sh deploy-apis
```

`api.json`:

```json
{
  "enabled": true,
  "name": "products-api",
  "host": "{subdomain}-products",
  "document_root": "public",
  "php_version": "8.3",
  "sqlite": "database.sqlite",
  "env": { "APP_MODE": "competition" }
}
```

| Field | |
|---|---|
| `enabled` | `false` to ignore the API (the template is disabled) |
| `name` | lowercase letters, digits and dashes; containers are named `<username>_<name>` |
| `host` | host name without the domain; must contain `{subdomain}` and/or `{username}` (e.g. `{subdomain}-products` → `qwer-products.<domain>`) |
| `document_root` | folder served by Apache, relative to the API folder (default `.`); files outside it are not reachable |
| `php_version` | optional, default `8.3` |
| `sqlite` | optional initial SQLite database, copied once per competitor to `data/apis/<name>/<username>/` |
| `env` | optional extra environment variables |

In the PHP code:
- `getenv('DB_PATH')`: the competitor's copy of the SQLite database, `getenv('COMPETITOR')`: the username,
  `getenv('API_NAME')`, and every variable of `env`;
- every path that is not a file is sent to `index.php` (routing without `.htaccess`);
- CORS headers are added by Traefik, competitors' frontends can call the API from their own subdomain;
- the code is mounted **read-only**: a fix in `config/apis/` applies at once to every competitor, no deploy needed.

Commands:
- `sudo ./competition.sh deploy-apis`: after adding, enabling, disabling or changing the `api.json` of an API.
  Existing databases are kept; containers of disabled APIs are removed. `init` deploys the APIs as well.
- `sudo ./competition.sh reset-api <name> [competitor]`: replace a competitor's database (or everyone's) by
  the initial one.
- `sudo ./competition.sh recreate apis` or `recreate comp01_products-api`, like any other service.

`check-config` also checks every enabled `api.json`: fields, files, and host names that would collide with a
module (`<subdomain>-<module>`), another API, or `git`, `npm`, `wud`, `pma`, `db`.

### Backup and restore

A backup is a `backups/backup-<date>-<manual|clean>.tar.gz` archive containing `data/` (Gitea repositories and
container registry, both MySQL databases, Verdaccio packages, runner registrations), `config/`,
`dynamic/docker/competitors.yaml`, `.env` and `competition.lock`.

- `backup` stops the services while copying (MySQL files must not change during the copy) and starts them again.
  Expect a short downtime.
- `clean` backs up after the services are stopped and before deleting anything. If the backup fails, nothing is
  deleted. Use `--no-backup` to skip it.
- `restore` checks the archive, runs `clean` (so the current state is backed up too), extracts the archive and
  starts every service. The backup can be restored in another directory or on another machine:
  paths are never stored, they are derived from the location of `competition.sh`.

Backups are never deleted automatically; remove old ones from `backups/` yourself.

### Recreating a single service

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

**Verbose mode** (shows debug information). The flag goes before the command:
```bash
sudo ./competition.sh -v init
sudo ./competition.sh --verbose start
```

**Help:** `./competition.sh --help` lists every command, `./competition.sh <command> --help` shows its arguments
and examples (no `sudo` needed for help).

**Note:** If you have previously run `sudo ./competition.sh init`, make sure to clean the environment first by running `sudo ./competition.sh clean` before initializing again. This ensures a fresh setup and avoids potential conflicts. Do NOT manually delete `competition.lock`, it's there as a safeguard and should only be cleared with `sudo ./competition.sh clean`

### Configuration
The environment is configured using a JSON file at `config/main.json`. Below is the structure:

```json
{
  "domain": "local.skill17.com",
  "enable_https": true,
  "username": "admin",
  "password": "your_secure_password",
  "modules": ["module-a", "module-b"],
  "frameworks": {
    "frameworks_repo": "https://github.com/your-org/frameworks.git",
    "allowed_frameworks": ["laravel", "react", "vuejs"]
  },
  "competitors": [
    {
      "name": "Competitor 1",
      "username": "comp01",
      "password": "comp01_password",
      "subdomain": "comp01"
    },
    {
      "name": "Competitor 2",
      "username": "comp02",
      "password": "comp02_password",
      "subdomain": "comp02"
    }
  ]
}
```

**Key settings:**

1. **domain**: The main domain for the competition.
   - Example: `local.skill17.com`

2. **enable_https**: Enable (`true`) or disable (`false`) HTTPS/SSL.
   - Set to `true` for production, `false` for local development

3. **username / password**: Admin credentials for Gitea.
   - These are used to create the admin user in Gitea

4. **modules**: List of module/project names for competitors.
   - Example: `["frontend", "backend", "devops"]`

5. **frameworks.frameworks_repo**: Git repository URL containing framework templates.
   - These templates are cloned and imported for competitors to use
   - **frameworks.allowed_frameworks** (optional): only these frameworks are imported; all of them if omitted

6. **competitors**: Array of competitor configurations.
   - Each competitor needs: `username`, `password`, and `subdomain`; `name` is optional (display only)
   - Databases are automatically created per competitor per module

**Validation:** `init` and `import-frameworks` check `config/main.json` first and list every problem before
doing anything. To check it on its own: `sudo ./competition.sh check-config`. Rules:
- `username`, `subdomain` and module names: lowercase letters, digits and dashes only (they are used in
  domain names, container names, image paths and database names), each username and subdomain used once;
- passwords: no quotes, backslashes or control characters such as tabs (they are inserted as-is in SQL
  and JSON);
- `enable_https`: `true` or `false` (not a string).

### Manual Installation

If you prefer to install dependencies manually instead of using `sudo ./competition.sh setup`:

**For Debian/Ubuntu:**
```bash
# Update package manager
sudo apt update
sudo apt upgrade -y

# Install basic tools
sudo apt install -y curl wget git ca-certificates gnupg lsb-release

# Install jq (JSON parser)
sudo apt install -y jq

# Install Docker (Official Docker installation)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to docker group (to use docker without sudo)
sudo usermod -aG docker $USER
newgrp docker  # Activate the new group

# Install certbot for SSL (optional but recommended)
sudo apt install -y certbot
```

**Verify Installation:**
```bash
docker --version
docker compose version
jq --version
git --version
```

## Using the Environment

- **Git Server (Gitea):**
  Access through the `git` subdomain of your configured domain.
  - Example: `https://git.local.skill17.com`
  - Default admin: `admin` / `your_secure_password`

- **Competitors' Work:**
  Competitors' projects can be accessed using their subdomain and the module name.
  - Format: `https://<subdomain>-<module_name>.<domain>`
  - Example: `https://qwer-module-a.local.skill17.com`

- **Database Entries:**
  MySQL is automatically configured with:
  - Per-competitor databases: `comp01_module_a`, `comp01_module_b`, etc.
  - Automatic user creation with appropriate permissions
  - Users can access only their own databases

## Competitor Workflow

### Creating a Repository

1. **Access Gitea:**
   Open your Git server (e.g., `https://git.local.skill17.com`) and log in using your credentials.

2. **Choose a Framework Template:**
   Go to `organization -> frameworks` to pick a framework template for your repository. The templates include necessary Docker configurations and GitHub Actions workflows ready to use.

3. **Use the Template:**
   Click **"Use this template"** to create your repository. Name the repository to match the module name defined in the configuration file.
   - Example: If your module is `module-a`, name the repository `module-a`.

4. **Environment Setup:**
   The framework template automatically includes:
   - Dockerfile for containerization
   - GitHub Actions workflow for CI/CD
   - `.npmrc` with correct registry configuration (auto-replaced with your domain)
   - GitHub Actions secrets (USER, PASS, DOMAIN, NPM_REGISTRY_URL, SERVER_IP)

5. **Test the Setup:**
   Make a commit to verify that GitHub Actions are working correctly. The workflow should build and push your image to `git.domain/username/module_name:version`.

### Cloning and using the Repository

1. Clone the repository:
   ```bash
   git clone https://<username>:<password>@git.local.skill17.com/<username>/<module_name>.git
   cd <module_name>
   ```

2. Install dependencies (if using Node.js):
   ```bash
   npm install
   ```

3. Develop your code:
   - Edit, commit, and push frequently
   - Use branches for features/fixes
   - Always keep your README updated

4. Push your code:
   ```bash
   git push origin main
   ```
   This triggers the GitHub Actions workflow which builds your Docker image and pushes it to the registry.

## Troubleshooting

### Services not starting
- Check Docker is running: `docker ps`
- View logs: `docker compose -f services/20-gitea/compose.yaml logs`
- Use verbose mode: `sudo ./competition.sh -v init`

### Configuration issues
- Verify `config/main.json` is valid JSON: `jq . config/main.json`
- Check that `frameworks_repo` is accessible
- Ensure all required fields are present

### Cleaning up
- To reset everything: `sudo ./competition.sh clean`
- To stop without removing data: `sudo ./competition.sh stop`
- To restart: `sudo ./competition.sh start`

## Development

`competition.sh` is generated with [bashly](https://bashly.dev) from the sources in `src/`. **Do not edit
`competition.sh` directly**, edit `src/` and regenerate it. The services in `services/` are loaded at runtime
and need no regeneration.

```
bashly-settings.yml        # bashly settings (source dir, production mode)
services/                  # one directory per service, see "Services" below
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

### Tests

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

### Services

Each service is a directory `services/<NN>-<name>/`:

```
services/
  10-traefik/      compose.yaml
  20-gitea/        compose.yaml  service.sh   # wait_ready, post_init (admin, tokens, orgs, frameworks)
  30-runners/      compose.yaml
  40-mysql/        compose.yaml  service.sh   # pre_init (competitors.sql)
  50-verdaccio/    compose.yaml  service.sh   # pre_init (storage permissions)
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
