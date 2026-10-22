# `services` Commands

## Purpose

Install and manage services in native or container mode.

## Usage

```bash
plumectl services supported
plumectl services supported --mode=native
plumectl services supported --mode=docker-lite
plumectl --json services supported --mode=native
plumectl services status
plumectl services status --running
plumectl services status --running --wide
plumectl services status --watch
plumectl services status --watch=5 --running
plumectl services status @web --mode=laradock-bridge
plumectl --json services status
plumectl services install php
plumectl services install all
plumectl services up php
plumectl services up php84
plumectl services status php-fpm-8.4
plumectl services health php82
plumectl services up all
plumectl services up @queue
plumectl services use mariadb --mode=native
plumectl services up @core --mode=native
plumectl services down php
plumectl services down all
plumectl services down group:web
plumectl services health
plumectl services health --running
plumectl services health --watch
plumectl services health redis --mode=native
plumectl services health @web --mode=laradock-bridge
plumectl services logs redis --tail=50 --mode=native
plumectl services logs @web --running --mode=laradock-bridge
plumectl services logs php --follow --mode=laradock-bridge
plumectl services logs php --watch --mode=laradock-bridge
plumectl services exec workspace --mode=docker-lite
plumectl services exec workspace bash --mode=docker-lite
plumectl services exec composer --mode=laradock-bridge
plumectl services containers --mode=docker-lite
plumectl services containers --mode=laradock-bridge
plumectl services containers nginx --mode=docker-lite
plumectl services laradock init --mode=laradock-bridge --path=/opt/laradock
plumectl services laradock sync --mode=laradock-bridge --path=/opt/laradock
plumectl services laradock check --mode=laradock-bridge --path=/opt/laradock
plumectl services config show --mode=laradock-bridge
plumectl services config add @web --mode=laradock-bridge
plumectl services config remove redis --mode=laradock-bridge
plumectl services config reset --mode=laradock-bridge
plumectl services workspace status --mode=docker-lite
plumectl services workspace up --mode=docker-lite
plumectl services workspace apply --mode=docker-lite
plumectl services workspace refresh --mode=docker-lite
plumectl services workspace down --mode=docker-lite
plumectl services workspace init --mode=docker-lite --path=/abs/project
plumectl services workspace reinit --mode=docker-lite --path=/abs/project
plumectl services web ensure
plumectl services web sync-config --reload
plumectl services web port 80 --reload
plumectl services update
plumectl services install php --version=8.3
plumectl services up horizon --version=latest
```

## Parameters

- target service: `all`, service name (`php`, `redis`, `mariadb`, `mysql`, `phpmyadmin`, `pgadmin`, `postgres`, `mongodb`, `rabbitmq`, `memcached`, `mongo_webui`, `redis_webui`, `mailpit`, etc.) or service group (`@core`, `@web`, `@db`, `@cache`, `@queue`, `group:web`)
  - native `@core`: php, composer, `web`, DB engines, redis, phpmyadmin, pgadmin, mailpit (**no queue**; D-144)
  - native `@web`: registry `web` (active `PLUME_WEB_SERVER_DRIVER`; `nginx`/`apache2`/`caddy` display variant)
  - native `@queue`: supervisor + horizon (host worker, D-147); php_worker registry-only
  - `services use mariadb|mysql|postgres`: native DB XOR + UI mapping — [services-use.md](./services-use.md)
  - contract: [native-service-contract.md](../operations/native-service-contract.md)
  - adapter-contract aliases are accepted independent of mode:
    - `php-fpm -> php`
    - `workspace -> composer`
    - `php-worker -> php_worker`
    - `laravel-horizon -> horizon`
    - php target aliases: `php84`, `php-fpm-8.4`, `php82`, `php-fpm-8.2`
      - these targets normalize to the `php` service and the related PHP version is resolved automatically
- for `supported`:
  - `--mode=native|docker-lite|laradock-bridge`
  - text output also ends with the mode-appropriate group list
- `status`:
  - returns `enabled`, `running`, `health`, `port`, `version` fields
  - `--running` / `--running-only` / `--active`: show only `running=true` services
  - `--wide`: print the full port list in the text table without truncation
  - `--watch[=N]`: refresh text output every `N` seconds (default `2`)
  - in watch mode, refresh interval and last update time are printed at the top
  - with a group target (`@web`, `group:queue`), lists only that group's services
  - the web server row is shown as `nginx|apache2|caddy` instead of `web`
  - in native/docker-lite modes only the active driver (`PLUME_WEB_SERVER_DRIVER`) is `enabled=true`
  - in laradock-bridge mode, `enabled` is computed from compose presence, not env toggle semantics
  - laradock-bridge text output also prints active `MODE` and `CONTEXT` headers
  - in laradock-bridge mode the `PORT` column may show all published host ports (`80,443`, `2222,3000`) instead of a single port
- `health`:
  - native: `healthy` (live probe), `stopped` (dead PID/port), `starting` (HTTP PID live), `registry` (horizon/supervisor/meilisearch/minio — no host daemon)
  - without a target service, lists all services
  - `--running` / `--running-only` / `--active`: list only `running=true` services
  - `--watch[=N]`: refresh text output every `N` seconds (default `2`)
  - in watch mode, refresh interval and last update time are printed at the top
  - web server health view is given as `nginx|apache2|caddy` rows
  - with a group target (`@web`, `group:db`), lists only that group's services
- `logs`:
  - `services logs <service> [--tail=N]`
  - accepts group and `all` targets (`@web`, `@queue`, `all`)
  - `--follow` / `-f`: keep the log stream open
  - `--watch`: alias for `--follow`
  - `--running` / `--running-only` / `--active`: read logs only for running services
- `exec`:
  - `services exec <service> [--cmd=sh|bash] [--no-tty] [-- ...]`
  - shortcut: `services exec <service> <cmd> [args...]` (example: `services exec workspace bash`)
  - runs `docker compose exec` in docker-lite and laradock-bridge modes
  - default shell is `sh`
  - the `composer` alias is redirected to the `workspace` container
  - blocked in native mode
- `containers`:
  - `services containers [service] [--mode=docker-lite|laradock-bridge] [--path=...]`
  - lists docker-lite/laradock-bridge compose containers via `docker compose ps`
  - blocked in native mode
- `laradock`:
  - `services laradock init|sync|check --mode=laradock-bridge [--path=...] [--repo=...] [--branch=...]`
  - `init`: clones the default `https://github.com/laradock/laradock.git` repo (or pull/sync on an existing repo), records mode path as laradock-bridge.
  - `sync`: updates the laradock repo via git fetch/pull (repo url override supported).
- `web` (native, nginx driver):
  - `services web ensure [--port=80] [--dry-run] [--no-republish]` — guarantee port 80 (D-151)
  - `services web sync-config [--port=80] [--dry-run] [--reload]`
  - `services web port <n> [--dry-run] [--reload]`
  - Main nginx listen management is on by default; see [services-web.md](services-web.md).
  - `check`: runs strict configuration checks:
    - whether required services exist in the compose file (`nginx,apache2,caddy,mariadb,mysql,phpmyadmin,php-fpm,redis,laravel-horizon,php-worker,workspace`)
    - whether `.env` has compatible `APP_CODE_PATH_CONTAINER=/var/www`
    - whether `APP_CODE_PATH_HOST` can be resolved
    - whether registered site paths in laradock-bridge mode are under `APP_CODE_PATH_HOST`
- `config`:
  - `services config show|add|remove|reset --mode=laradock-bridge`
  - manages the desired service set in SQLite
  - `show`: lists `desired` and `resolved` service sets separately for the active Laradock context
  - `add/remove`: accepts a single service (`php`, `redis`, `workspace`) or group (`@web`, `@db`, `@queue`, `@core`)
  - `reset`: clears the desired service set for the related Laradock context
- Laradock runtime rule:
  - `services status|health|logs|up|down|exec|containers --mode=laradock-bridge` first requires a valid Laradock context.
  - Path priority:
    - `--path=/abs/laradock`
    - `mode path set laradock-bridge /abs/laradock`
  - Path is not guessed; without a valid path the command fail-fasts.
  - Runtime source-of-truth is live `docker compose` state; state env/SQLite is used as cache.
  - In Laradock, `services status` and `services supported` show the compose service list, not a static Plume list.
  - In Laradock, `services up all` and `services down all` target the desired service set in SQLite, not every service in compose.
  - `services up all` runs in safe-order: `db -> php -> queue -> web -> others`.
  - `services down all` runs in reverse safe-order: `web -> queue -> php -> db -> others`.
  - If a service fails during `services up all`, services started earlier in that command are stopped in reverse order (rollback).
  - If the desired set is empty, `up/down all` fails; define the service set first with `services config add ...`.
  - Dependencies from `depends_on` are not written into the desired set; they are only included in the resolved set.
  - This keeps user intent (`desired`) separate from the compose dependency graph (`resolved`).
  - group targets are also supported:
    - `@core`: basic laravel runtime surface (`workspace`, `php-fpm`, `php-worker`, `laravel-horizon`, active web/db links)
    - `@web`: web server services (`nginx`, `apache2`, `caddy`, `openresty`)
    - `@db`: database/broker/cache services (`mariadb`, `mysql`, `postgres`, `redis`, `rabbitmq`, etc. when present in compose)
    - `@queue`: queue worker/horizon services
  - Alias commands remain supported:
    - `php` -> `php-fpm`
    - `composer` -> `workspace`
    - `horizon|supervisor` -> `laravel-horizon`
  - `enabled` calculation is mode-isolated:
    - native/docker-lite: Plume env toggles
    - laradock-bridge: whether the service exists in Laradock compose
- `workspace`:
  - `services workspace init|reinit|apply|up|refresh|rebuild|down|status --mode=docker-lite [--path=/abs/project] [--profile=<name>]`
  - runs docker compose lifecycle commands at the collective workspace level
  - `reinit`: cleans existing plume docker-lite stub files and runs `init` again
  - `apply`: detects changes and decides automatically
    - context/build-effective change: `up -d --force-recreate --build`
    - config/.env/conf change: `up -d --force-recreate`
    - if container is down: `up -d`
    - if no change: no-op
  - `refresh` (`rebuild` alias): runs `docker compose up -d --force-recreate --build`
  - PHP matrix reconcile (automatic):
    - the desired `php-fpm` service set is computed from `PLUME_PHP_DEFAULT_VERSION` + `PLUME_PHP_INSTALLED_VERSIONS`.
    - required services (`php-fpm`, `php81-fpm`, `php82-fpm`, `php83-fpm`, `php84-fpm`) are brought `up` automatically.
    - obsolete php-fpm clone services removed from env are cleaned with `rm -f -s`.
    - on `services workspace up`, if `.env.docker-lite` php/workspace changes are detected, it switches to `--force-recreate --build` mode automatically.
- `--version`:
  - selectable on `services install|up|update`.
  - for `horizon`, works independently of `--version` and service env versions.
- for `update`:
  - detects services that changed `false -> true` in config
  - installs and starts newly enabled services (per policy)
- Dependency rule:
  - `supervisor` is required for `horizon` (native mode)
  - for `phpmyadmin`, `PMA_DB_ENGINE` (`mariadb|mysql`, alias: `PMA_ENGINE`) selection is required; the selected engine must be `enabled=true`
- Phase 2 note (current):
  - Default (`PLUME_NATIVE_HOST_PROVISION=false`): non-PHP services use state/port orchestration.
  - `PLUME_NATIVE_SERVICE_AUTO_PROVISION=true` (default): in native mode, `enabled=true` services host install+start via `services up` (Phase 17); disable with `--no-provision`.
  - `PLUME_NATIVE_HOST_PROVISION=true`: real host install/start/stop for all supported services (brew/apt/dnf + npm web UI).
  - Native **mailpit** (D-109): macOS Homebrew `brew install mailpit` + `brew services start mailpit`; `services up mailpit` also tries the brew path without the global provision flag. Linux native: WARN + exit 2; docker-lite or manual install.
  - For native `php`, `services install php --mode=native --version=<x.y>` tries real host binary install:
    - macOS (brew): `php@x.y`
    - Linux (apt): `phpx.y-cli` + `phpx.y-fpm`
  - Native `services up php82` / `services up php --version=8.2` (and other version aliases) start the host FPM service after binary verification:
    - macOS (brew): `brew services start php@8.2` (if the formula is not installed the `php@x.y` name is used; for the default version it may fall back to the installed `php` formula)
    - Before start, the Homebrew `www.conf` pool `listen` is aligned to the Plume canonical unix socket (D-107); if the socket is missing the command `exit 2` with a php-fpm log hint.
    - Linux (apt): `systemctl start phpx.y-fpm`
    - With `PLUME_PHP_NATIVE_INSTALL_DRIVER=mock`, real brew is not invoked in smoke/test environments.
  - Multiple PHP versions can run at once (Homebrew: a separate unix socket per version, e.g. `php@8.2-fpm.sock`). Plume does not stop other versions when starting one; the site nginx upstream must target the version-specific socket or `--php-upstream` (see D-105). `services up php82` sets the Homebrew pool `listen` line to that socket path (see D-107).
- `--version` behavior:
  - for `plume`, `php` can be run with an alias or direct version (`php`, `php83`, `8.3`).
  - for non-php services, `latest` or semver/text version formats are accepted (validation is strict in the stub phase).

## Output / Exit Codes

- `0`: operation succeeded
- `2`: prereq/validation error

## Examples

```bash
plumectl services install php
plumectl services up php
plumectl services up php82
plumectl services up php --version=8.2
plumectl services down php
plumectl services health php
plumectl services logs php --tail=20
plumectl services update
plumectl services status
plumectl services supported --mode=native
```

## Native runtime notes (Phase 6)

- During native `install/up` steps, per-service runtime state is kept in `~/.config/plume/state/services_runtime_native.env`.
- Native install privilege semantics:
  - Linux: root/sudo is required for host package install.
  - macOS + brew: the install command runs as a normal user (brew does not run as root).
- Native `services up php --version=<x.y>`:
  - if the target PHP version is missing from the matrix or host cli/fpm binary is missing, auto-provision is triggered.
  - if auto-provision succeeds, the version is added to `php.env` state and service start continues.
  - macOS Homebrew: `brew services start php@x.y` is run for the target version (`php82` alias → `8.2`).
  - Homebrew FPM: before `services up`, `www.conf` `listen` is updated to the canonical unix socket; on failed bind/missing socket `exit 2` (D-107).
  - Other versions' FPM (e.g. php@8.3) is not stopped automatically; multiple versions can run together via unix sockets.
- Native `services up php` (no version) enforces the full PHP matrix by default:
  - verifies/provisions all of `PLUME_PHP_INSTALLED_VERSIONS` + the default version at binary level.
  - Toggle: `PLUME_PHP_AUTOPROVISION_ALL_ON_UP=true|false` (default: true).
- Native `services up php` extension auto-sync:
  - with `PLUME_PHP_EXTENSIONS_AUTO_SYNC=true`, the extension contract (preset + toggle + matrix) is synced/verified.
  - `PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE`:
    - `matrix` (default): sync all of `PLUME_PHP_INSTALLED_VERSIONS + default`.
    - `target`: sync only the `services up php --version=<x.y>` target version.
    - `default`: sync only `PLUME_PHP_DEFAULT_VERSION`.
  - strict behavior: `PLUME_PHP_EXTENSIONS_STRICT=true`
- For port-using services, if the default port is taken a fallback port is chosen and written to `services_ports_native.env`.
- `services logs` output is read by default from `~/.config/plume/logs/services/native/<service>.log`.

## Docker-lite runtime notes (Phase 7)

- `services install/up/down --mode=docker-lite` commands operate on a compose-service basis.
- In docker-lite, `composer` is not listed as a separate service; it is used as a command inside the `workspace` container.
- In docker-lite, `supervisor` and `horizon` map to the same `laravel-horizon` container.
- Compose file is resolved with deterministic priority: `--path` > `mode path` > remembered compose > working directory (`docker-compose.yml|compose.yml`).
- Even without `--path`, if a recorded `mode path` (`mode path set docker-lite ...`) exists, compose is also resolved from there automatically.
- `services workspace init --mode=docker-lite --path=...` generates a docker-lite stub (compose + web conf + env stub) in the target directory.
- With `mode=docker-lite` + `mode path` set, `<mode-path>/.env.docker-lite` is loaded automatically.
- Full stack lifecycle is managed with `services workspace up|down|status --mode=docker-lite`.
- Without `--profile`, the default `core` profile is used.
- Docker-lite port behavior parallels native: if the default port is taken a fallback is assigned and written to the state file.
- Web server assumption is a single active web server + default host ports `80/443` (`PLUME_WEB_PORT`, `PLUME_WEB_HTTPS_PORT`).
- `services workspace up --mode=docker-lite` first extracts the image list via `compose config --images`, pulls missing images one by one with `docker pull`; if pull fails, `up` fails before starting.
- If the pull step fails, similar-image suggestions based on `docker search` are printed.
- When PHP versions change (`PLUME_PHP_DEFAULT_VERSION`, `PLUME_PHP_INSTALLED_VERSIONS`), `workspace up/apply` detects this automatically; if images are missing it pulls via compose pull/up and rebuilds/recreates php-fpm and workspace.
- `services health/logs --mode=docker-lite` attach to container state via docker compose `ps/logs`.
- `services exec --mode=docker-lite|laradock-bridge` finds the compose file via mode/path and can enter a container shell from any directory.
- After `services install/up/workspace up`, the global mode/path context lock becomes active; `--force` is required to change mode/path.

## Mailpit (native, D-109)

Development mail capture with macOS Homebrew:

```bash
# Manifest
# services.yml → mailpit: { enabled: true }
plumectl services provision --from-manifest

# or directly
PLUME_MAILPIT_ENABLED=true plumectl services install mailpit --mode=native
plumectl services up mailpit --mode=native
```

- UI default: `http://127.0.0.1:8025` (`PLUME_MAILPIT_PORT`).
- Laravel `.env`: `MAIL_MAILER=smtp`, `MAIL_HOST=127.0.0.1`, `MAIL_PORT=1025` (Mailpit SMTP).
- Linux native: no automatic install; `plumectl services up mailpit` WARN + exit 2 — `--mode=docker-lite` or [Mailpit](https://github.com/axllent/mailpit) manually.
- Nginx port 80/8080 diagnose (D-109): `plumectl doctor web` — see [services-web.md](./services-web.md).

## Manifest subcommands (native)

```bash
plumectl services manifest show
plumectl services provision --from-manifest [--dry-run]
```

- `manifest show`: `effective_*` lines (web/php/database + `effective_<service>_enabled` / `_version` for all registry services). See [services-manifest.md](../operations/services-manifest.md), [services-provision.md](./services-provision.md).

## Error scenarios

- Service not supported
- Port could not be assigned
- Package manager step failed
- Requested version not supported
- Horizon could not start (supervisor missing/not active)
- Install/start error during `services update` reconcile

Horizon/supervisor native: [services-horizon.md](./services-horizon.md), [services-supervisor.md](./services-supervisor.md). Diagnose: `plumectl doctor supervisor`.
