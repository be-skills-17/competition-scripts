# Troubleshooting

## Services not starting
- Check Docker is running: `docker ps`
- View logs: `docker compose -f services/20-gitea/compose.yaml logs`
- Use verbose mode: `sudo ./competition.sh -v init`

## Configuration issues
- Verify `config/main.json` is valid JSON: `jq . config/main.json`
- Check that `frameworks_repo` is accessible
- Ensure all required fields are present

## Cleaning up
- To reset everything: `sudo ./competition.sh clean`
- To stop without removing data: `sudo ./competition.sh stop`
- To restart: `sudo ./competition.sh start`

## Gitea uses a lot of CPU every few seconds

WUD checks every competitor image in Gitea's registry every 10 seconds (`WUD_WATCHER_LOCAL_CRON` in
`services/60-wud/compose.yaml`). Three settings keep this cheap:
- WUD logs in with a `read:package` token instead of the admin password: Gitea checks a password with its slow
  password hash (about 60 ms of CPU each). The token is created by WUD's `pre_up` hook and kept in
  `dynamic/wud/registry.env` (readable by root only).
- Gitea is declared as a **custom** registry (`WUD_REGISTRY_CUSTOM_GITEA_*`), not with WUD's `gitea` provider: the
  `gitea` provider asks a new registry token for every request, the custom one caches it (one per image, 60 s).
- Competitor containers have no `wud.watch.digest` label: every CI build pushes a new `1.0.<unix time>` tag, so
  digests are not needed, and watching them made WUD ask the manifest of the running image every check.

On an installation made before these settings, or if the token was deleted in Gitea:

```bash
sudo ./competition.sh recreate wud
```

The competitor labels are written by `init` only (`dynamic/competitors/compose.yaml`). To remove the digest
labels from an existing installation without `init`:

```bash
sudo sed -i '/"wud.watch.digest=true"/d; /"wud.registry=gitea.private"/d' dynamic/competitors/compose.yaml
sudo ./competition.sh recreate competitors
```

If Gitea does not answer when the hook runs, WUD keeps its previous token, or falls back to the admin password
(with a warning): run `recreate wud` again once Gitea is up. A longer `WUD_WATCHER_LOCAL_CRON` reduces the load
further, at the cost of a longer delay between a competitor's push and its deployment.
