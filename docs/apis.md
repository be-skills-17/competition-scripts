# Provided APIs (native PHP)

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

## Documentation (Swagger)

Put an OpenAPI description (JSON only) next to `api.json`: `config/apis/<folder>/openapi.json`. The template has an
example. It is shown with Swagger UI (served locally, nothing loaded from the internet):
- in the **portal** (`https://<domain>/api-docs.php`, logged-in competitors, link in the "API fournies" section):
  the `servers` of the file are replaced by the competitor's own instance, so "Try it out" calls their API and
  their database only;
- in the **dashboard** (`http://localhost:8090/api-docs.html`, "Documentation des API" card): documentation only,
  no "Try it out" and no server.

Both read the file live (`config/apis/` is mounted read-only; the dashboard's nginx serves nothing but
`openapi.json`): a change shows at once. A new API still needs `deploy-apis` to appear. `check-config` reports an
`openapi.json` that is not valid JSON; an API without one simply has no documentation.

Commands:
- `sudo ./competition.sh deploy-apis`: after adding, enabling, disabling or changing the `api.json` of an API.
  Existing databases are kept; containers of disabled APIs are removed. `init` deploys the APIs as well.
- `sudo ./competition.sh reset-api <name> [competitor]`: replace a competitor's database (or everyone's) by
  the initial one.
- `sudo ./competition.sh recreate apis` or `recreate comp01_products-api`, like any other service.

`check-config` also checks every enabled `api.json`: fields, files, and host names that would collide with a
module (`<subdomain>-<module>`), another API, or `git`, `npm`, `wud`, `pma`, `db`.
