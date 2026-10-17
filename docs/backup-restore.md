# Backup and restore

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
