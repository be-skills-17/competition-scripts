# Competitor portal

The main domain (`https://<domain>/`) serves a portal for competitors:
- **without logging in**: links to Gitea and phpMyAdmin, with their icons;
- **after logging in with their competition username and password** (the ones of `config/main.json`), their own
  information, each value with a "Copier" button: credentials (password hidden until "Afficher"), MySQL host,
  port and user, `.npmrc` line, and for each module whether the Git repository is created yet, the website URL,
  database name and repository URL with the credentials (`https://<user>:<password>@git.<domain>/...`, ready for
  `git clone`; the password is hidden on screen, the copied URL is complete), plus the URLs of the provided APIs. A competitor only ever sees their own
  information;
- **the creation and deletion of their modules' repositories** (see below).

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

## Creating and deleting a module's repository

A module whose repository is missing has a **Créer** button: a popup lists the framework templates (the
`frameworks` organization in Gitea, limited to `allowed_frameworks` when the list is set), and creates the private
repository `<username>/<module>` from the chosen one (Gitea's "Use this template", with its content). The
repository always gets the module's name.

Each template is shown with its logo, `public/img/frameworks/<template>.svg` (from [Simple Icons](https://simpleicons.org),
CC0, filled with the brand color). A template without a logo gets a generic `</>` icon: to add one, drop
`<template>.svg` in that folder (served at once, no restart).

The buttons are in the last column of the modules table. A created repository has a link to its page in Gitea
(Gitea icon) and a **Supprimer** button (bin icon): the popup asks to type `Valider` (checked by the browser and
again by the portal), then deletes the repository in Gitea. This cannot be undone.

Both are done with the competitor's own credentials, only for the modules of `config/main.json`. As with "Use this
template" in Gitea, creating a repository does not run its workflow: the website keeps its current image until
the competitor's first push.

Login: the password is compared with `hash_equals`, a failed attempt waits 0.8 s, the session id is renewed after
login, forms carry a CSRF token, and the session cookie is `HttpOnly`, `SameSite=Lax` and `Secure` over HTTPS.

`/dashboard/` shows the portal too: the domain used to serve the Traefik dashboard, whose `/` answered a
permanent redirect to `/dashboard/` that browsers keep in cache (`public/dashboard/index.php`).

## Code layout

Plain PHP, no framework and no build. Changes are served at once (both folders are mounted read-only).

```
services/85-portal/
  app/                       PHP code, outside the document root (never reachable by URL)
    bootstrap.php            loads lib/, starts the session, reads portal.json
    lib/session.php          session cookie, CSRF token, redirect after POST, message shown once (flash)
    lib/auth.php             login / logout / logged-in competitor
    lib/gitea.php            Gitea API with the competitor's own credentials: their repositories, templates,
                             creation from a template, deletion
    lib/competitor.php       what a logged-in competitor sees (repository state, clone URLs...): templates
                             only display values computed here; module_action() creates / deletes repositories
    lib/view.php             escaping, render(), versioned asset URLs, icons, copy buttons, section bands
    templates/               HTML only: layout, login, home, sections/{access,modules,apis}
  public/                    document root
    index.php                entry point: handles the POSTs (login, logout, create / delete a repository),
                             renders the layout
    assets/portal.css        styles
    assets/portal.js         tooltip, copy / reveal buttons, repository popups
    img/, logo.svg           service icons and logo (not in img/icons: Apache reserves /icons/)
    img/frameworks/          logos of the framework templates (<template>.svg)
    dashboard/index.php      same page at /dashboard/ (see above)
```

To add a section: compute its values in `competitor_view()` (`lib/competitor.php`), add a template in
`templates/sections/` and render it from `templates/home.php`. Changing `config/main.json` (competitors, modules): `sudo ./competition.sh recreate portal`.

## Existing installation

`init` starts the portal. On an environment initialized before it existed, the domain still shows the Traefik
dashboard: move Traefik's dashboard to the server and start the portal with

```bash
sudo ./competition.sh recreate traefik portal
```
