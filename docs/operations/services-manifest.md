# Native services manifest (`services.yml`)

Central manifest similar to Laradock’s `docker-compose.yml`: configures which stack components are targeted in native mode. **`.env` remains the environment layer**; if the same key is defined in both YAML and `.env`, **`.env` wins**.

## File location

| File | Purpose |
|-------|------|
| `~/.config/plume/services.yml` | Persistent user manifest (default) |
| `templates/services.yml.example` | In-repo template (all registry services) |
| `PLUME_SERVICES_MANIFEST_FILE` | Manifest path override |

If the manifest is missing, `plumectl init host` copies the template to `~/.config/plume/services.yml` (does not overwrite an existing file).

## Merge order

1. `lib/config/defaults.sh` (embedded defaults; internal `PLUME_*`)
2. `plume_env_apply_laradock_aliases` (short name ↔ `PLUME_*` sync)
3. `services.yml` (configured service definitions; `${REDIS_ENABLED}` etc. placeholders are resolved from the defaults environment in this step)
4. `~/.config/plume/.env` (last word; `plume_load_env` + aliases reapplied)

`${VAR}` interpolation: Laradock `docker-compose`-like — references such as `${PHPMYADMIN_ENABLED}` in manifest values are resolved from the current environment during manifest apply (after defaults + aliases). If the same key is defined in `.env`, **`.env` wins** (the manifest only provides wiring/discoverability). Old `${PLUME_*_ENABLED}` placeholders still work for backward compatibility.

`host.env` is for machine detection; it is **not** for service toggles (see D-098).

## Schema (version `version: 1`)

Special blocks (`web`, `php`, `database`, `provision`) + registry services (block YAML; `${PLUME_*}` values are written quoted).

Full example: `templates/services.yml.example`.

### YAML → environment mapping (summary)

| YAML section | Field | Environment variable |
|-------------|------|-----------------|
| `web` | `engine` | `PLUME_WEB_SERVER_DRIVER` |
| `web` | `manage_main_config` | `PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG` |
| `web` | `http_port` | `PLUME_NATIVE_NGINX_HTTP_PORT`, `PLUME_WEB_PORT` |
| `web` | `auto_provision` | `PLUME_SITE_AUTO_PROVISION_WEB`; if `true` then `PLUME_NATIVE_HOST_PROVISION=true` |
| `web` | `enabled` | `PLUME_WEB_SERVER_ENABLED` |
| `php` | `enabled` | `PLUME_PHP_ENABLED` |
| `php` | `default_version` | `PLUME_PHP_DEFAULT_VERSION`, `PLUME_PHP_VERSION` |
| `php` | `versions[]` | `PLUME_PHP_INSTALLED_VERSIONS` (comma-separated) |
| `php` | `extensions_profile` | `PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE` |
| `database` | `engine` | `PLUME_MARIADB_ENABLED` / `PLUME_MYSQL_ENABLED` (single engine; both forbidden on native brew — D-128) |
| `database` | `version` | `PLUME_MARIADB_VERSION` or `PLUME_MYSQL_VERSION` |
| `database` | `auto_start` | DB start during provision (manifest read; not env) |
| `provision` | `interactive: false` | `PLUME_NONINTERACTIVE=true` |
| `provision` | `on_first_run: true` | Once on first native bootstrap (or `init host`): `services provision --from-manifest`; when done, `state/on_first_run_provision.done` |

### Registry services (single table — D-104)

Each row: `services.<name>.enabled` → `PLUME_*_ENABLED`, optional `version` → `PLUME_*_VERSION`. Source: `plume_services_manifest_env_mapping_rows` + `lib/services/registry.sh` (`plume_service_env_key`).

| YAML `services.<name>` | Enabled env | Version env |
|------------------------|-------------|-------------|
| `composer` | `PLUME_COMPOSER_ENABLED` | `PLUME_COMPOSER_VERSION` |
| `phpmyadmin` | `PLUME_PHPMYADMIN_ENABLED` | `PLUME_PHPMYADMIN_VERSION` |
| `pgadmin` | `PLUME_PGADMIN_ENABLED` | `PLUME_PGADMIN_VERSION` |
| `mariadb` | `PLUME_MARIADB_ENABLED` | `PLUME_MARIADB_VERSION` |
| `mysql` | `PLUME_MYSQL_ENABLED` | `PLUME_MYSQL_VERSION` |
| `postgres` | `PLUME_POSTGRES_ENABLED` | `PLUME_POSTGRES_VERSION` |
| `redis` | `PLUME_REDIS_ENABLED` | `PLUME_REDIS_VERSION` |
| `memcached` | `PLUME_MEMCACHED_ENABLED` | `PLUME_MEMCACHED_VERSION` |
| `rabbitmq` | `PLUME_RABBITMQ_ENABLED` | `PLUME_RABBITMQ_VERSION` |
| `mongodb` | `PLUME_MONGODB_ENABLED` | `PLUME_MONGODB_VERSION` |
| `mongo_webui` | `PLUME_MONGO_WEBUI_ENABLED` | `PLUME_MONGO_WEBUI_VERSION` |
| `redis_webui` | `PLUME_REDIS_WEBUI_ENABLED` | `PLUME_REDIS_WEBUI_VERSION` |
| `mailpit` | `PLUME_MAILPIT_ENABLED` | `PLUME_MAILPIT_VERSION` |
| `meilisearch` | `PLUME_MEILISEARCH_ENABLED` | `PLUME_MEILISEARCH_VERSION` |
| `minio` | `PLUME_MINIO_ENABLED` | `PLUME_MINIO_VERSION` |
| `supervisor` | `PLUME_SUPERVISOR_ENABLED` | `PLUME_SUPERVISOR_VERSION` |
| `horizon` | `PLUME_HORIZON_ENABLED` | `PLUME_HORIZON_VERSION` |
| `php_worker` | `PLUME_PHP_WORKER_ENABLED` | `PLUME_PHP_WORKER_VERSION` |

`database.engine` can be used together with `mariadb`/`mysql` sections; **on native Homebrew only one engine must be active** (`database.engine: mariadb` or `mysql`). If both are `true`, manifest load warns and `services start`/`provision` errors (D-128). phpMyAdmin lists only operational (health-passing) engines.

On registry rows, use quoted block YAML for `${REDIS_ENABLED}` placeholders (see `templates/services.yml.example`). Old `${PLUME_REDIS_ENABLED}` remains backward compatible.

```yaml
redis:
  enabled: "${REDIS_ENABLED}"
phpmyadmin:
  enabled: "${PHPMYADMIN_ENABLED}"
postgres:
  enabled: "${POSTGRES_ENABLED}"
  version: "16"
```

### Native host provision vs enable-only

| Service | Manifest `enabled` | `provision --from-manifest` (native) |
|--------|-------------------|--------------------------------------|
| web (nginx/apache2) | Yes | Install + start |
| mariadb, mysql, redis | Yes | Install + start (`database.auto_start` for DB) |
| postgres, mongodb, rabbitmq, memcached, phpmyadmin, pgadmin, mongo_webui, redis_webui | Yes (Phase 17–20) | Install + start; OS matrix see [native-stack-os-matrix.md](./native-stack-os-matrix.md) |
| mailpit | Yes (env) | macOS Homebrew: install + start; Linux: warning (docker-lite / manual) |
| php (`versions[]`) | Yes | Best-effort brew/apt PHP install + matrix registration |
| meilisearch, minio | Yes (env) | Native toggle-only (`health=registry`, D-146); driver backlog |
| phpmyadmin, composer, horizon, … | Yes (env) | **horizon/supervisor:** native host worker (D-147); php_worker registry-only |

Laradock-bridge-specific compose names (`workspace`, `php-fpm`) are documented as comments in the template; the native loader does not read those rows.

### Queue: `horizon`, `php_worker`, `supervisor` (D-113)

| Service | `services.yml` | Native host provision | Runtime |
|--------|----------------|----------------------|------------|
| `horizon` | `enabled` → `PLUME_HORIZON_ENABLED` | brew/apt `supervisor` + program | `services up horizon` — supervisor gate; native `php artisan horizon` (D-147) |
| `php_worker` | `enabled` → `PLUME_PHP_WORKER_ENABLED` | **No** | Usually docker-lite / laradock **php-worker** container or manual `queue:work` |
| `supervisor` | `enabled` → `PLUME_SUPERVISOR_ENABLED` | brew/apt `supervisor` + system unit | Plume program registry + OS conf.d (D-149) |

**Docker-lite:** Compose alias `laravel-horizon` ↔ Plume service name `horizon` (and `supervisor` can map to the same container). See [services.md](../commands/services.md).

**Laradock-bridge:** `laravel-horizon`, `php-worker` compose services; the manifest only loads env toggles and does not change compose.

**Operational CLI:** `plumectl queue status`, `plumectl queue list`; when Horizon is on, `services status horizon`. `PLUME_HORIZON_PATH` or a registered site artisan path is required.

## Commands

To see effective configuration (`effective_*` lines, adapter-parse):

```bash
plumectl init onboarding          # checklist + effective_* lines
plumectl services manifest show
```

Greenfield host (Homebrew / apt / dnf — brew shim in mock smokes):

```bash
plumectl env init
plumectl init host                  # host.env + services.yml bootstrap
plumectl init host --apply          # native provision from manifest
# First CLI session (provision.on_first_run: true in manifest): automatic provision (once)
# or
plumectl services provision --from-manifest
plumectl services provision --from-manifest --dry-run
```

If an extra PHP version is not in the manifest:

```bash
plumectl php install 8.4
plumectl init onboarding --fix      # brew services nginx/php
```

## macOS: steps that are not automatic

- **Full Disk Access**: `nginx` and `php-fpm` binaries (not Plume or plume.sh). See [macos-permissions.md](./macos-permissions.md).
- **Project root under Desktop / Documents / Downloads**: TCC; prefer `~/Sites` or `~/Code`.
- **Port 80**: Homebrew nginx defaults to 8080; use `manage_main_config: true` + `services web sync-config --reload`, or stay on 8080.

## Backward compatibility

If the manifest file is missing, the loader is a no-op; only `.env` + defaults behavior continues. Missing YAML keys do not change existing env/defaults values.

## Related decisions

- D-130 — Laradock-style env names in config; alias layer `plume_env_apply_laradock_aliases`
- D-128 — manifest `${VAR}` interpolation, native DB status health probe, brew dual-engine guard
- D-108 — `provision.on_first_run` automatic manifest provision
- D-104 — full registry manifest mapping
- D-103 — `services.yml` native manifest MVP
- D-098 — `host.env`
- D-100 — interactive install prompts
