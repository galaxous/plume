# Environment Contract

Plume settings can be managed via `.env`.

## Shared Rule

- Plume-specific variable prefix: `PLUME_` (state, mode, site, native driver settings)
- Stack service toggle/port/credential: **Laradock-style short names** (example `REDIS_ENABLED`, `MARIADB_PORT`) — in canonical config files (D-130)
- Default example file: `.env.example`
- Variables use the same naming standard regardless of mode.
- Default config file: `plume.yml` (project-local site manifest)
- Native stack manifest: `~/.config/plume/services.yml` — merge order: defaults → `services.yml` (`${REDIS_ENABLED}` etc. resolved) → `~/.config/plume/.env` (env wins). See [services-manifest.md](./services-manifest.md)

## Mode-Specific Prefixes

- Native: `PLUME_NATIVE_*`
- Docker-lite: `PLUME_DOCKER_LITE_*`
- Laradock-bridge: `PLUME_LARADOCK_*`

Note:

- For native and docker-lite, the primary config source is the shared `PLUME_*` variables.
- `PLUME_DOCKER_LITE_*` variables are used for adapter-level override and service-name mapping.

## Default Toggle Policy

- Default `true`: `nginx`, `php`, `composer`, `mariadb`
- Other services default `false`
- Later `false -> true` changes are reconciled with `services update`.

## Site/Adapter Variables

- `PLUME_SITE_HOSTS_SYNC=true|false`: enables/disables hosts-file updates during publish/remove.
- `PLUME_SITE_HOSTS_REQUIRED=true|false`: whether the command fails if hosts write fails.
- `PLUME_SITE_RELOAD_REQUIRED=true|false`: whether the command fails if `site publish --reload` fails.
- `PLUME_SITE_RELOAD_VALIDATE=true|false`: whether to run a config test before native reload (`nginx -t`, `apachectl/httpd -t`, `caddy validate`).
- `PLUME_SITE_NGINX_STRICT=true|false`: requires target include path + lint + reload pipeline on native nginx publish.
- `PLUME_NGINX_INCLUDE_DIR=/path/to/include`: explicitly sets the native nginx strict publish include directory.
- `PLUME_SITE_APACHE2_STRICT=true|false`: requires include path + lint + reload pipeline on native apache2 publish.
- `PLUME_APACHE2_INCLUDE_DIR=/path/to/include`: explicitly sets the native apache2 strict publish include directory.
- `PLUME_SITE_CADDY_STRICT=true|false`: requires include path + lint + reload pipeline on native caddy publish.
- `PLUME_CADDY_INCLUDE_DIR=/path/to/include`: explicitly sets the native caddy strict publish include directory.
- `PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true|false`: compose-file requirement before docker-lite publish/reload.
- `PLUME_DOCKER_LITE_*_SERVICE=<compose-service-name>`: service-name → compose service mapping override (example: `PLUME_DOCKER_LITE_REDIS_SERVICE=redis-cache`).
- `PLUME_PHP_VERSION`: docker-lite default `php-fpm` image tag source.
- PHP extension matrix:
  - `PLUME_PHP_EXT_PRESET=none|laravel-core|queue|media|full`
  - `PLUME_PHP_EXT_PRESET_81`, `PLUME_PHP_EXT_PRESET_82`, ...
  - `PLUME_PHP_EXTENSIONS_GLOBAL`
  - `PLUME_PHP_EXTENSIONS_81`, `PLUME_PHP_EXTENSIONS_82`, ...
  - `PLUME_PHP_EXT_ENABLE_<EXT>=true|false`
  - `PLUME_PHP_EXT_ENABLE_<VER>_<EXT>=true|false` (example: `PLUME_PHP_EXT_ENABLE_84_XDEBUG=true`)
  - `PLUME_PHP_EXT_DISABLE_<VER>_<EXT>=true|false`
  - `PLUME_PHP_EXTENSIONS_STRICT=true|false`
  - `PLUME_PHP_EXTENSIONS_AUTO_SYNC=true|false`
  - `PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE=matrix|target|default` — `target` is recommended for daily macOS dev (`docs/operations/local-dev-macos.md`)
  - `PLUME_PHP_EXT_INSTALL_DRIVER=brew|apt|mock|...`
- Native per-version php-fpm upstream override:
  - `PLUME_NATIVE_PHP_FPM_UPSTREAM` (default php)
  - `PLUME_NATIVE_PHP_FPM_UPSTREAM_81`, `..._82`, `..._84`
- `PLUME_NATIVE_HOST_PROVISION=true|false`: real host package install/start/stop for `web`, `mariadb`, `mysql`, `redis` (and apache2 driver) in native mode. Default `false` (state simulate).
- `PLUME_NONINTERACTIVE=true|false`: skip macOS permission menu and TTY brew/sudo confirmations (CI; compatible with global `--yes`). Native MariaDB/MySQL root password bootstrap does not attempt passwordless TCP (no tty `Password:` prompt; D-134). Hosts sync: CI uses `sudo -n` only (D-136); interactive terminals may prompt via `/dev/tty` (D-159 `plume_fs_copy_elevated`).
- `PLUME_NATIVE_DB_HOSTS_SYNC=true|false`: `/etc/hosts` alias sync after native mariadb/mysql up (default `true`; smoke/CI: `false`).
- `PLUME_INTERACTIVE=true|false`: interactive prompt behavior outside or inside a TTY (see `docs/operations/macos-permissions.md`).
- `PLUME_SITE_AUTO_PROVISION_WEB=true|false`: automatic host install/start when the web server is missing during native `site publish --reload`. Default `true`.
- Native Homebrew nginx main-config port management:
  - `PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=true|false`: main `nginx.conf` listen management (default `true`, D-151).
  - `PLUME_NATIVE_NGINX_HTTP_PORT`: target HTTP port (default `80` — portless `http://site.test`).
  - `PLUME_NATIVE_NGINX_ENSURE_ON_PUBLISH` / `PLUME_NATIVE_NGINX_ENSURE_ON_WEB_UP`: automatic ensure (default `true`).
  - `plumectl services web ensure`: sync + elevated bind + site republish.
  - `PLUME_NATIVE_NGINX_HTTP_PORT`: target HTTP port (default `80`).
  - `PLUME_NATIVE_NGINX_MAIN_CONF`: main nginx config file path override.
  - `PLUME_NATIVE_HOMEBREW_HTTP_PORT`: forces effective port when rendering site `port: 80` (e.g. `8080`; overrides even if main config is 80).
- `PLUME_WEB_SERVER_VERSION`, `PLUME_MARIADB_VERSION`, `PLUME_MYSQL_VERSION`, `PLUME_POSTGRES_VERSION`, `PLUME_REDIS_VERSION`: primary source for docker-lite image tags.
- `PLUME_DOCKER_LITE_PHP_FPM_IMAGE=php:<ver>-fpm-alpine`: default php-fpm image override (optional).
- `PLUME_LARADOCK_STRICT=true|false`: strict path+compose+container preflight for laradock-bridge publish/reload.
- `PLUME_LARADOCK_COMPOSE_FILE=/abs/path/docker-compose.yml`: laradock-bridge compose file path override.

Laradock path policy:

- Laradock path is not managed via `.env`.
- Primary sources:
  - temporary override with `--path=<laradock-dir>`
  - or registered global state with `mode path set laradock-bridge <laradock-dir>`
- Runtime Laradock commands do not guess the path; they fail fast if there is no valid Laradock path.

## Runtime State Files

- Native:
  - `PLUME_STATE_DIR/services_runtime_native.env`
  - `PLUME_STATE_DIR/services_ports_native.env`
- Docker-lite:
  - `PLUME_STATE_DIR/services_runtime_docker-lite.env`
  - `PLUME_STATE_DIR/services_ports_docker-lite.env`
- SQLite mirror (phase start):
  - `PLUME_STATE_DB_FILE` (default: `PLUME_STATE_DIR/plume-state.db`)
  - tables: `services`, `runtime_events`, `locks`

## Precedence Order

1. CLI flags
2. Global state (`mode use`, `mode path set`)
3. `.env` (except mode/path)
4. YAML config
5. Built-in defaults

Note:

- `PLUME_MODE`, `PLUME_DOCKER_LITE_COMPOSE_FILE`, and `PLUME_LARADOCK_PATH` values inside `.env` are not applied.

## Stack Service Env (Laradock mapping)

Stack service toggle/port/credential settings are written in `.env` and `services.yml` with **Laradock-style short names**. At runtime, `plume_env_apply_laradock_aliases_*` (`lib/common/stack_service_env.sh`) synchronizes:

1. **outward** (after defaults, before manifest): `PLUME_*` → short name (only when short name is empty; `${REDIS_ENABLED}` interpolation)
2. **refresh** (after manifest): `PLUME_*` updated by the manifest → short name (always)
3. **inward** (after `.env`): short name → `PLUME_*` (`.env` / CLI short name wins)

Env loading (`plume_load_env`): if the file defines only one end of an alias pair (example `PLUME_REDIS_ENABLED=true`), the mapped short name is not kept as a pre-defaults/manifest value; after source, if only `PLUME_*` exists, the short name is synced to it (D-131).

`PLUME_*`-only (old style) still works; deprecated.

| Laradock (canonical) | Internal (`PLUME_*`) | Default |
|-------|------------------|------------|
| `REDIS_ENABLED` | `PLUME_REDIS_ENABLED` | `false` |
| `MARIADB_ENABLED` | `PLUME_MARIADB_ENABLED` | `true` |
| `MYSQL_ENABLED` | `PLUME_MYSQL_ENABLED` | `false` |
| `PHPMYADMIN_ENABLED` | `PLUME_PHPMYADMIN_ENABLED` | `false` |
| `POSTGRES_ENABLED` | `PLUME_POSTGRES_ENABLED` | `false` |
| `REDIS_PORT` | `PLUME_REDIS_PORT` | `6379` |
| `REDIS_PASSWORD` | `PLUME_REDIS_PASSWORD` | `secret_redis` |
| `MONGODB_PORT` | `PLUME_MONGODB_PORT` | `27017` |
| `MONGO_USERNAME` | `PLUME_MONGODB_USERNAME` | `root` |
| `MONGO_PASSWORD` | `PLUME_MONGODB_PASSWORD` | `example` |
| `PLUME_MONGODB_DATABASE` | — | `admin` |
| `RABBITMQ_NODE_HOST_PORT` | `PLUME_RABBITMQ_PORT` | `5672` |
| `RABBITMQ_MANAGEMENT_HTTP_HOST_PORT` | `PLUME_RABBITMQ_MANAGEMENT_PORT` | `15672` |
| `RABBITMQ_DEFAULT_USER` / `RABBITMQ_DEFAULT_PASS` | `PLUME_RABBITMQ_USER` / `PASSWORD` | `guest` / `guest` |
| `MONGO_WEBUI_PORT` | `PLUME_MONGO_WEBUI_PORT` | `8082` (Plume; Laradock often `3000`) |
| `PLUME_MONGO_WEBUI_URI` | `MONGO_WEBUI_MONGO_URL` | automatic (`mongodb://user:pass@127.0.0.1:27017/admin`) |
| `PLUME_MONGO_WEBUI_USERNAME` / `PASSWORD` | mongo-express basic auth | `admin` / `pass` |
| `REDIS_WEBUI_PORT` | `PLUME_REDIS_WEBUI_PORT` | `8083` (Plume; Laradock often `9987`) |
| `REDIS_WEBUI_USERNAME` / `PASSWORD` | `PLUME_REDIS_WEBUI_USERNAME` / `PASSWORD` | `laradock` / `laradock` |
| `REDIS_WEBUI_CONNECT_HOST` / `REDIS_WEBUI_CONNECT_PORT` | `PLUME_REDIS_WEBUI_HOST` / `REDIS_PORT` | `127.0.0.1` / `6379` |
| `MEMCACHED_ENABLED` / `MEMCACHED_PORT` | `PLUME_MEMCACHED_*` | `false` / `11211` |
| `MAILPIT_ENABLED` / `MAILPIT_PORT` / `MAILPIT_SMTP_PORT` | `PLUME_MAILPIT_*` | `false` / `8025` / `1025` |
| `SUPERVISOR_ENABLED` / `HORIZON_ENABLED` | `PLUME_SUPERVISOR_ENABLED` / `PLUME_HORIZON_ENABLED` | `false` |
| `PLUME_HORIZON_PATH` | Legacy single-program fallback (artisan path) | empty → horizon-enabled sites; else first site/cwd |
| `PLUME_HORIZON_REQUIRE_SUPERVISOR` | `up horizon` requires supervisor | `true` |
| `PLUME_NATIVE_SUPERVISOR_MAIN_CONF` | Main supervisord.conf override (smoke) | automatic |
| `PLUME_NATIVE_SUPERVISOR_PROGRAMS_DIR` | Program drop-in override (smoke) | automatic |

After changes, runtime: `services restart <svc> --mode=native` or `services env set ... --restart`. For Redis also `services redis sync-config --reload`. See [services-env.md](../commands/services-env.md), [services-redis.md](../commands/services-redis.md).

Native Redis config management (`PLUME_NATIVE_REDIS_MANAGE_CONFIG=true`, default): Plume produces `state/native/redis/plume-redis.conf` and adds an `include` inside system `redis.conf`.

Native DB/broker config (`PLUME_NATIVE_MARIADB_MANAGE_CONFIG`, `PLUME_NATIVE_POSTGRES_MANAGE_CONFIG`, `PLUME_NATIVE_MONGODB_MANAGE_CONFIG`, `PLUME_NATIVE_RABBITMQ_MANAGE_CONFIG`, default `true`):

| Laradock (canonical) | Internal (`PLUME_*`) | Default |
|-------|----------|------------|
| `MARIADB_PORT` | `PLUME_MARIADB_PORT` | `3306` |
| `MARIADB_ROOT_PASSWORD` | `PLUME_MARIADB_ROOT_PASSWORD` | `root` |
| `POSTGRES_PORT` | `PLUME_POSTGRES_PORT` | `5432` |
| `POSTGRES_USER` | `PLUME_POSTGRES_USER` | `postgres` |
| `POSTGRES_PASSWORD` | `PLUME_POSTGRES_PASSWORD` | `postgres` |
| `MYSQL_ROOT_PASSWORD` | `PLUME_MYSQL_ROOT_PASSWORD` | `root` |
| `MYSQL_PORT` | `PLUME_MYSQL_PORT` | `3307` |

After changes: `plumectl services restart <svc> --mode=native` (config sync is automatic).
