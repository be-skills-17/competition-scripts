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

## Quick start

```bash
sudo ./competition.sh setup          # install Docker, jq, git, curl... (once)
# edit config/main.json
sudo ./competition.sh check-config   # check the configuration
sudo ./competition.sh init           # create and start everything
./competition.sh --help              # every command
```

## Documentation

**Organizers**

| | |
|---|---|
| [Installation](docs/installation.md) | Dependencies, automatic (`setup`) or manual installation |
| [Configuration](docs/configuration.md) | `config/main.json`: domain, admin, modules, frameworks, competitors, validation rules |
| [Commands](docs/commands.md) | Every command of `competition.sh`, verbose mode, help |
| [Recreating a service](docs/recreate.md) | `recreate`, and what each service keeps or loses |
| [Frameworks](docs/frameworks.md) | Re-importing the framework templates into Gitea |
| [npm packages](docs/npm.md) | npmjs cut off by default, templates' dependencies cached (`prefetch-npm`, `npm-proxy`) |
| [Provided APIs](docs/apis.md) | Native PHP APIs deployed for every competitor (`deploy-apis`, `reset-api`) |
| [Dashboard](docs/dashboard.md) | Local dashboard (http://localhost:8090): competitors, services, server metrics; Portainer (https://localhost:9443) |
| [Backup and restore](docs/backup-restore.md) | `backup`, `restore`, and the backup made by `clean` |
| [Troubleshooting](docs/troubleshooting.md) | Common problems |

**Competitors**

| | |
|---|---|
| [Competitor portal](docs/portal.md) | `https://<domain>/`: log in to see and copy your credentials, URLs and databases |
| [Using the environment](docs/usage.md) | Gitea, websites, databases, creating a repository from a template, pushing code |

**Developers**

| | |
|---|---|
| [Development](docs/development.md) | Project structure, regenerating `competition.sh` with bashly, tests |
| [Services](docs/services.md) | `services/<NN>-<name>/` directories, hooks, adding a service |