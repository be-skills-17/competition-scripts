# Commands

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

# Cache the npm dependencies of the framework templates in Verdaccio, then cut npmjs off (init does it too)
sudo ./competition.sh prefetch-npm
sudo ./competition.sh npm-proxy on      # or off; without argument: show the mode

# Deploy the provided PHP APIs of config/apis/, reset a competitor's API database
sudo ./competition.sh deploy-apis
sudo ./competition.sh reset-api products-api comp01

# Back up the whole environment into backups/
sudo ./competition.sh backup

# Restore a backup (a file, a name from backups/, or "latest")
sudo ./competition.sh restore latest

# Clean the entire system (removes volumes, images, configs); a backup is made first
sudo ./competition.sh clean
sudo ./competition.sh clean --no-backup
```

**Verbose mode** (shows debug information). The flag goes before the command:
```bash
sudo ./competition.sh -v init
sudo ./competition.sh --verbose start
```

Details: [recreating a service](recreate.md), [frameworks](frameworks.md), [npm](npm.md), [APIs](apis.md),
[backup and restore](backup-restore.md).

**Help:** `./competition.sh --help` lists every command, `./competition.sh <command> --help` shows its arguments
and examples (no `sudo` needed for help).

**Note:** If you have previously run `sudo ./competition.sh init`, make sure to clean the environment first by running `sudo ./competition.sh clean` before initializing again. This ensures a fresh setup and avoids potential conflicts. Do NOT manually delete `competition.lock`, it's there as a safeguard and should only be cleared with `sudo ./competition.sh clean`
