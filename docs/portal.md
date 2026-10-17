# Competitor portal

The main domain (`https://<domain>/`) serves a portal for competitors:
- **without logging in**: links to Gitea and phpMyAdmin, with their icons;
- **after logging in with their competition username and password** (the ones of `config/main.json`), their own
  information, each value with a "Copier" button: credentials (password hidden until "Afficher"), MySQL host,
  port and user, `.npmrc` line, and for each module whether the Git repository is created yet, the website URL,
  database name and repository URL with the credentials (`https://<user>:<password>@git.<domain>/...`, ready for
  `git clone`; the password is hidden on screen, the copied URL is complete), plus the URLs of the provided APIs. A competitor only ever sees their own
  information.

## How it works

`services/85-portal`: a `php:8.3.26-apache` container routed by Traefik on `Host(<domain>)`, serving
`public/index.php` (plain PHP, sessions, no database).

The data comes from `dynamic/portal/portal.json`, generated from `config/main.json` and the enabled APIs before
every start of the portal (`pre_up` hook) and by `deploy-apis`. It is mounted outside the document root, readable
by Apache only (`640`, group `www-data`), and does not contain the admin credentials.

A module whose repository is not created yet is greyed out: no link to its website and no copy of its
repository URL (the database stays copyable, it exists from the start).

The repository status is asked to Gitea (internal URL `GITEA_API_URL`) with the logged-in competitor's own
credentials: it lists the repositories they own, private ones included, without any admin token. If Gitea does
not answer, the status shows "Gitea injoignable".

Login: the password is compared with `hash_equals`, a failed attempt waits 0.8 s, the session id is renewed after
login, forms carry a CSRF token, and the session cookie is `HttpOnly`, `SameSite=Lax` and `Secure` over HTTPS.

`/dashboard/` shows the portal too: the domain used to serve the Traefik dashboard, whose `/` answered a
permanent redirect to `/dashboard/` that browsers keep in cache (`public/dashboard/index.php`).

## Editing

`services/85-portal/public/index.php` (and `logo.svg`): changes are served at once, the folder is mounted
read-only. Changing `config/main.json` (competitors, modules): `sudo ./competition.sh recreate portal`.

## Existing installation

`init` starts the portal. On an environment initialized before it existed, the domain still shows the Traefik
dashboard: move Traefik's dashboard to the server and start the portal with

```bash
sudo ./competition.sh recreate traefik portal
```
