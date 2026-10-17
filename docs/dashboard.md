# Dashboard and server metrics

An organizer dashboard is served **on the server only**: <http://localhost:8090>. It is published on
`127.0.0.1` and has no Traefik route, so it is not reachable from the network. From another machine, use an SSH
tunnel: `ssh -L 8090:localhost:8090 <user>@<server>`, then open <http://localhost:8090>.

It shows:
- **Competitors**: one card per competitor with a link to each module and provided API. The list is read from
  the Traefik API (routers `compXX_<name>`); if Traefik does not answer, it falls back to `config/main.json`.
- **Services**: links to Gitea, phpMyAdmin, Verdaccio, WUD, and the **Traefik dashboard**, which is also
  server-only: <http://localhost:8091/dashboard/> (port `8080` of Traefik published on `127.0.0.1`, no public
  route; the main domain serves the [competitor portal](portal.md)).
- **Server**: CPU, memory, disk, load and uptime, refreshed every 3 seconds, with an "élevé" (≥ 75 %) or
  "critique" (≥ 90 %) label; and the containers using the most CPU.

- **Documentation des API**: a card, when an API is enabled, opening `api-docs.html`: the `openapi.json` of the
  provided APIs in Swagger UI, documentation only (see [apis.md](apis.md#documentation-swagger)).

## How it works

Two services:

| Service | |
|---|---|
| `services/65-glances` | [Glances](https://nicolargo.github.io/glances/) API (no web UI), sees the host's processes (`pid: host`) and the containers (Docker socket, read-only). Not routed by Traefik. |
| `services/80-dashboard` | nginx serving `html/index.html`, and proxying `/traefik/` to the Traefik API and `/glances/` to Glances over the internal `gitea` network: the page calls its own origin, no CORS needed. |

`config.js` (domain, modules, competitors without passwords) is generated from `config/main.json` into
`dynamic/dashboard/` before every start of the dashboard (`pre_up` hook).

Glances runs in a container: network traffic is not shown (it would only see the container's own interfaces),
and the disk is the one holding Docker's files.

## Editing the page

The page is `services/80-dashboard/html/index.html` (static HTML, no build). Changes are served at once (the
folder is mounted read-only in nginx); reload the browser. The list of services and their icons is the
`SERVICES` / `ICONS` constants in the page.

## Existing installation

`init` starts both services. On an environment initialized before they existed:

```bash
sudo ./competition.sh recreate glances dashboard
```
