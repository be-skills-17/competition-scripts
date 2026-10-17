# npm packages (Verdaccio)

Competitors install npm packages through Verdaccio (`npm.<domain>`, the framework templates' `.npmrc` point to
it). **npmjs is cut off by default**: `init` caches the dependencies of every framework template, then cuts npmjs
off. Competitors (and their CI builds) can install exactly what the templates need, nothing else.

There is nothing to configure: the packages come from the templates themselves, as imported in Gitea (the
`frameworks` organization). For every `package.json` of every template, with its `package-lock.json`:
1. the npm proxy is turned on and `npm install` is run through Verdaccio, in a throwaway `node` container, once
   per platform: the exact versions of the lockfile, and all their dependencies, get cached in `data/verdaccio`;
2. the npm proxy is turned off: Verdaccio no longer knows npmjs;
3. everything is installed again, offline, and must give exactly the same packages for every platform.

If a download or the check fails, **the npm proxy is left on** (a partial cache with npmjs cut off would break
every install) and the error says what is missing; `init` goes on. Run `prefetch-npm` again once fixed.

This runs during `init` and `import-frameworks` (new templates may need new packages). To run it on its own:

```bash
sudo ./competition.sh prefetch-npm                  # cache, cut off, check (about 2 minutes for 4 templates)
sudo ./competition.sh prefetch-npm --keep-online    # cache but leave npmjs reachable
```

## A competitor needs another package

```bash
sudo ./competition.sh npm-proxy on    # npmjs reachable: the competitor installs the package, Verdaccio caches it
sudo ./competition.sh npm-proxy off   # cut off again: the package stays available from the cache
sudo ./competition.sh npm-proxy       # show the current mode
```

A package added this way stays in `data/verdaccio` (and in backups), but a new `init` starts from an empty cache:
if every competitor needs it, add it to the template instead.

## Versions

Only cached versions can be installed. The templates' lockfiles decide which ones: a competitor running
`npm install react@18` while the react template uses react 19 gets an error, so does `npm install <package>` for
a package no template uses. Use `npm-proxy on` for these cases.

## Platforms

Some packages download a native binary for the platform as an optional dependency (esbuild, rollup, swc...).
npm silently skips an optional dependency it cannot download, so a package cached for one platform only would
install elsewhere without its binary and fail at run time. Binaries are cached for:

| Platform | |
|---|---|
| `linux-x64` | Linux, glibc: competition PCs, Debian/Ubuntu, `node:lts` images |
| `linux-x64-musl` | Linux, musl: `node:*-alpine` images (e.g. the vuejs template's Dockerfile) |
| `win32-x64` | Windows |

The list is `VERDACCIO_PLATFORMS` in `services/50-verdaccio/lib/verdaccio.sh` (e.g. add `darwin-arm64`).

## How the proxy is turned off

`config/verdaccio/config.yaml` is generated from the versioned `config/verdaccio/config.template.yaml` (edit the
template, not the generated file). Proxy on: the template as is. Proxy off: the `uplinks` and `middlewares`
sections and every `proxy:` line are removed. Removing `proxy:` alone is not enough: Verdaccio 6 still queries
the declared uplinks.

Verdaccio does not prevent competitors from using `https://registry.npmjs.org` directly: to really cut npm off,
block internet access at the network level.
