# `site` Command

## Purpose

The `plumectl site` family quickly adds a Laravel project to the system and registers it in a central web-server registry.

## Commands

```bash
plumectl site add --path=/abs/path --domain=myapp.test[,www.myapp.test] --server=nginx|apache2|caddy
plumectl site add --path=/abs/path --domain=myapp.test --server=nginx --php=8.2 --publish
plumectl site add --path=/abs/path --domain=myapp.test --server=nginx --cert-id=cert-myapp --https-port=443 --publish
plumectl site update <site-id> --clear-cert --publish --reload
plumectl site update <site-id> --domain=myapp.test --server-config=/path/custom.conf --publish --reload
plumectl site publish <site-id> --reload
plumectl site publish <site-id> --dry-run
plumectl site list
plumectl site modes
plumectl site check <site-id>
plumectl site remove <site-id>
```

The `site` command operates at site level only. For site details use `plumectl site check <id>`. For interactive add, when `plumectl site add` runs on a TTY it prompts for `--path` and `--domain`.

## Add options

- `--path=<project_abs_path>`
- `--domain=<domain1,domain2>`
- `--server=nginx|apache2|caddy` (default: `nginx`)
- `--php=<8.1|8.2|8.3|8.4|default>` (default: `PLUME_PHP_DEFAULT_VERSION`)
- `--php-upstream=<host:port|unix:/sock>` (optional; per-site upstream override)
- `--mode=native|docker-lite|laradock-bridge` (default: active mode)
  - if given on `site update`, overrides the record mode
- `--port=<port>` (default: `80`)
- `--https-port=<port>` (default: `443`; used when a cert is bound)
- `--cert-id=<cert-id>` (cert id produced by `security cert issue`)
- `--clear-cert` (`site update` only: removes `cert_id`/`https_port` from the site record; snippet becomes HTTP-only, no HTTP→HTTPS redirect is written; certificate files remain in state)
- `--tls=false` (same as `--clear-cert`; `site update` only)
- `--document-root=<dir>` (default: `public`)
- `--horizon` (native: enables Horizon supervisor program for the site; writes `horizon: true`)
- `--no-horizon` (`site update` only: disables Horizon on the site record)
- `--publish` (writes the web server snippet)
- `--server-config=<abs_path>` (optional; path must exist and be readable)
- `--reload` (with `site publish`: reloads the `nginx|apache2|caddy` server)
- `--dry-run` (does not apply changes; prints the plan)
- `--force` (overrides domain/path conflicts)

Notes:

- If `--mode` is omitted, `project.mode` or `mode` is looked up in project-folder `plume.yml` first (`project.mode` wins).
- If `--php` / `--php-version` is omitted, `project.php_version` is used as a hint (installed-version validation still applies).
- If not found, the active mode (`plumectl mode current`) is used.
- If the site record has `mode`, `site update/publish/remove` prefer that mode.
- With `PLUME_SITE_RELOAD_REQUIRED=true`, if `--reload` fails the command returns `exit 2`.
- `PLUME_SITE_AUTO_PROVISION_WEB=true` (default): in native mode during `--reload`, if nginx/apache2 is not installed, automatic install and service start via `brew`/`apt` is attempted (`PLUME_NATIVE_HOST_PROVISION` not required; the publish flow temporarily enables host provision).
- With `PLUME_SITE_AUTO_PROVISION_WEB=false` you must install the web server manually: `PLUME_NATIVE_HOST_PROVISION=true plumectl services install web && services up web`.
- `PLUME_SITE_NGINX_STRICT_ON_RELOAD=true` (default): native `site publish --reload` writes the snippet under Homebrew `/opt/homebrew/etc/nginx/servers/` (or `PLUME_NGINX_INCLUDE_DIR`); otherwise config stays only in the `~/.config/plume/sites/nginx/` cache and nginx does not see it.
- macOS Homebrew nginx listens on **8080** in most installs (the formula intentionally maps 80→8080; no root required). Even if the site record has `port: 80`, render reads listen from the main config; if it is 8080 the snippet also becomes 8080 (can be forced with `PLUME_NATIVE_HOMEBREW_HTTP_PORT=8080`).
- Port **80** (portless `http://myapp.test`): `site publish <id> --reload` auto-ensures listen (no privileged reload during ensure when already on 80 — D-159); or run `plumectl services web ensure`. Details: [services-web.md](services-web.md). On macOS with root nginx, sudo may prompt once via `/dev/tty`.
- With `PLUME_SITE_RELOAD_VALIDATE=true` (default), a config test is required before reload in native mode:
  - nginx: `nginx -t`
  - apache2: `apachectl -t` or `httpd -t`
  - caddy: `caddy validate`
  - on macOS, if `nginx` is not on PATH, `bin/nginx` or `sbin/nginx` under the Homebrew prefix is tried automatically
- With `PLUME_SITE_NGINX_STRICT=true`, during native `server=nginx` publish:
  - the snippet is also written to the real include directory (`PLUME_NGINX_INCLUDE_DIR` or auto-detect),
  - `nginx -t` lint is required,
  - reload is required,
  - on lint/reload fail the target include is rolled back and publish fails.
- With `PLUME_SITE_APACHE2_STRICT=true`, during native `server=apache2` publish:
  - the snippet is also written to the real include directory (`PLUME_APACHE2_INCLUDE_DIR` or auto-detect),
  - `apachectl -t`/`httpd -t` lint is required,
  - reload is required,
  - on lint/reload fail the target include is rolled back and publish fails.
- With `PLUME_SITE_CADDY_STRICT=true`, during native `server=caddy` publish:
  - the snippet is also written to the real include directory (`PLUME_CADDY_INCLUDE_DIR` or auto-detect),
  - `caddy validate` lint is required,
  - reload is required,
  - on lint/reload fail the target include is rolled back and publish fails.
- With `PLUME_SITE_PORT_CONFLICT_CHECK=true`, a second site add/update using the same HTTP port is blocked (default: `false`).
- With `PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true`, a compose file is required for docker-lite publish/reload.
- With `PLUME_LARADOCK_STRICT=true`, publish/reload stops if laradock path/compose/container preflight fails.
- If mode changes via `site update`, cache/snippet artefacts for the old mode are cleaned up.
- The site record `php_version` field selects the upstream PHP-FPM service when generating the snippet:
  - default PHP: `php-fpm`
  - other versions: `php81-fpm`, `php82-fpm`, `php83-fpm`, `php84-fpm`
  - if the site `php_upstream` field is set, that value is used directly instead of the resolver.
  - in native mode a per-version upstream override can also be set:
    - `PLUME_NATIVE_PHP_FPM_UPSTREAM` (default php)
    - `PLUME_NATIVE_PHP_FPM_UPSTREAM_81`, `..._82`, `..._84`
  - without override, plume tries native socket discovery (`unix:/run/php/php8.2-fpm.sock`, `unix:/opt/homebrew/var/run/php@8.2-fpm.sock`, etc.)
  - if the socket is missing and Homebrew `php@X.Y` is installed, non-default versions do not fall into the shared `127.0.0.1:9000` pool; the canonical unix path (`php@8.2-fpm.sock`) is used. For the default PHP version, if the Homebrew pool has `listen = 127.0.0.1:9000`, that TCP upstream is used.
  - **Homebrew FPM socket:** the nginx snippet uses the canonical `unix:/opt/homebrew/var/run/php@8.2-fpm.sock`; the FPM pool must listen on the same path. `plumectl services up php82` (native) aligns the `www.conf` `listen` line (D-107). Manual check: `grep listen /opt/homebrew/etc/php/8.2/php-fpm.d/www.conf` and `ls -l /opt/homebrew/var/run/php@8.2-fpm.sock`.
  - `site update --php=... --publish` regenerates the snippet (header + `fastcgi_pass`); if only the yml record is updated without publish, the cache/nginx target stays old.
- When `cert_id` is given, snippet generation adds HTTPS blocks:
  - nginx: `listen <https-port> ssl` + `ssl_certificate`
  - apache2: SSL VirtualHost + redirect
  - caddy: `tls <crt> <key>`
- Without `cert_id` (or after `--clear-cert`), only an HTTP listener is produced; no nginx/apache2 HTTP→HTTPS redirect block is written.

## Exit / status codes

- `0`: operation succeeded
- `2`: validation and input error

## Record location

- Site records: `~/.config/plume/sites/<site-id>.yml`
- Site directory index: `~/.config/plume/sites/index.yml`
- Published snippet:
  - native: `~/.config/plume/sites/<server>/<site-id>.conf` (or `<PLUME_SITE_REGISTRY_DIR>/<server>/<site-id>.conf` if `PLUME_SITE_REGISTRY_DIR` is overridden)
  - docker-lite: `~/.config/plume/docker-lite/sites/<server>/<site-id>.conf`
  - laradock-bridge: `~/.config/plume/laradock-bridge/sites/<server>/<site-id>.conf`
- Hosts sync target file: `PLUME_HOSTS_FILE` (default `/etc/hosts`)
- With `PLUME_SITE_HOSTS_SYNC=true` (recommended), publish/update rewrites the site’s `/etc/hosts` lines (interactive sudo when needed — D-159). If sync is `false`, publish still updates nginx but warns that the browser may show `NXDOMAIN`.
- Even if hosts write fails (no permission), publish can be stopped with `PLUME_SITE_HOSTS_REQUIRED=true`.
- Prefer `plumectl site update <id> --domain=tunnelion.test --publish --reload` over hand-editing the YAML alone (same end state; clearer intent).

The file given with `--server-config` is copied directly into the snippet file.
`plumectl site publish <site-id> --reload` rewrites the current snippet and tries to reload the active web server (`nginx|apache2|caddy`).
With `PLUME_SITE_NGINX_STRICT=true`, `PLUME_SITE_APACHE2_STRICT=true`, or `PLUME_SITE_CADDY_STRICT=true`, native publish applies lint+reload for the strict pipeline even without `--reload`.
In that case `site publish --reload` does not trigger a second reload; the reload from the strict pipeline is reused.

Strict visibility fields in `site check` output:

- `mode`
- `strict_enabled`
- `strict_include_dir`
- `strict_include_target`

Browser access (native, especially macOS Homebrew nginx):

- `port`: logical HTTP port in the registry (usually `80`)
- `effective_http_port`: port actually listened on in the snippet (Homebrew nginx often `8080`)
- `url_http`: openable HTTP URL (e.g. `http://myapp.test:8080`)
- `url_https`: HTTPS URL when `cert_id` is set (e.g. `https://myapp.test`)
- `access_hint`: when registry is `80` but nginx only listens on `8080`; `http://myapp.test` (port 80) is refused — use `url_http` or `url_https`

### macOS: project under `Desktop` / `Documents` / `Downloads` (TCC)

Homebrew **nginx** and **php-fpm** usually run as a system user different from your login session. macOS **Transparency, Consent, and Control (TCC)** can restrict access to files under `~/Desktop`, `~/Documents`, and `~/Downloads`.

Symptoms:

- Browser or `curl`: `No input file specified.` (HTTP 404)
- Nginx error log: `Unable to open primary script: .../public/index.php (Operation not permitted)` or stat/open `Operation not permitted`

Fix (apply one):

1. **Move the project** — e.g. `~/Sites/...` or `~/Code/...` (outside Desktop/Documents/Downloads), then `plumectl site update <id> --path=... --publish --reload`
2. **Full Disk Access** — `plumectl init permissions --interactive` or `--open --reveal`; System Settings → Privacy & Security → Full Disk Access: add Homebrew **nginx** and **php-fpm** binaries; restart the services
3. **Diagnose** — `plumectl doctor web --mode=native` line `macos-site-tcc`; `plumectl doctor php` line `MACOS_TCC` (output suggests `init permissions --interactive`)

After `site add` and a successful `site update`, a **WARN** is printed for those folders (suggests `~/Sites/<project-name>`). Details: [local-dev-macos.md](../operations/local-dev-macos.md).

`site check --json` returns `data.tcc_risk: true` and TCC text in `warnings` (when the registry path is TCC-sensitive).

`site check --json` returns the same fields in `data`; if `access_hint` is set it is also added to the `warnings` array.

The `site list` text table keeps a fixed column order:

- `ID`
- `SERVER`
- `PHP`
- `PORT`
- `HTTPS`
- `CERT`
- `STATUS`
- `DOMAINS`
- `PATH`

Notes:

- `PATH` is always last.
- Header and row widths come from the same renderer, so alignment stays fixed.

The `site modes` text table provides a mode-based registry view:

- `ID`
- `MODE`
- `SERVER`
- `PHP`
- `STATUS`
- `PATH`

This command is used to audit which mode each site is held on, in bulk.

## Disabling HTTPS in local development (per site)

When the site record has `cert_id`, the nginx snippet redirects HTTP requests to HTTPS (`return 301`). To use HTTP only locally, remove the cert binding and rewrite the snippet (certificate files are not deleted):

```bash
plumectl site update site-1775207595-23239 --clear-cert --publish --reload
plumectl site check site-1775207595-23239
```

Then in the browser use the `url_http` value from `site check` output (on Homebrew nginx usually `http://myapp.test:8080`). To re-enable HTTPS, first `plumectl security cert issue --domains=myapp.test` (or an existing cert id), then `plumectl site update <id> --cert-id=<cert-id> --publish --reload`.

## Examples

```bash
plumectl site add --path=/Users/oguzhan/Code/myshop --domain=myshop.test --server=nginx --publish --server-config=/tmp/myshop.nginx.conf
plumectl site add --path=/Users/oguzhan/Code/myshop --domain=myshop.test --server=nginx --php=8.2 --php-upstream=unix:/tmp/php82-fpm.sock --publish
plumectl site add --path=/Users/oguzhan/Code/myapi --domain=myapi.test --server=caddy --publish
plumectl site add --path=/Users/oguzhan/Code/mytls --domain=mytls.test --server=nginx --cert-id=cert-mytls --https-port=4443 --publish
plumectl site list
plumectl site update site-1712345678-12345 --clear-cert --publish --reload
plumectl site check site-1712345678-12345
plumectl site remove site-1712345678-12345 --dry-run
plumectl site modes
```
