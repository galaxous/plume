# Service Support Matrix

This file shows in one place which services are supported in `native` and `docker-lite` modes.

Query via command:

```bash
plumectl services supported
plumectl services supported --mode=native
plumectl services supported --mode=docker-lite
```

## Matrix

| Service     | native | docker-lite | laradock-bridge | Notes |
|-------------|--------|-------------|-----------------|-------|
| nginx       | yes    | yes         | yes             | web server |
| apache2     | yes    | no          | opt             | if present in laradock compose |
| caddy       | yes    | yes         | opt             | if present in laradock compose |
| php-fpm     | yes    | yes         | yes             | php runtime |
| composer    | yes    | yes         | yes             | tool/runtime support |
| xdebug      | opt    | opt         | opt              | optional profile |
| mysql       | yes    | yes         | yes             | database |
| mariadb     | yes    | yes         | yes             | database |
| phpmyadmin  | yes    | yes         | yes             | mysql/mariadb selection via PMA_DB_ENGINE |
| postgres    | yes    | yes         | opt             | if present in laradock compose |
| pgadmin     | yes    | opt         | opt             | Laradock pgadmin parity; requires postgres |
| redis       | yes    | yes         | yes             | cache/queue |
| memcached   | yes    | no          | opt             | native brew/apt (D-145); if present in laradock compose |
| rabbitmq    | yes    | no          | opt             | if present in laradock compose |
| mongodb     | yes    | opt         | opt             | if present in laradock compose |
| mongo-webui | yes    | opt         | opt             | if present in laradock compose |
| mailpit     | yes    | yes         | opt             | native: macOS brew; Linux docker-lite |
| meilisearch | opt    | opt         | opt              | native toggle-only (D-146); driver backlog |
| minio       | opt    | yes         | opt             | native toggle-only (D-146); if present in laradock compose |
| supervisor  | yes    | opt         | yes             | system brew/systemd + program registry (D-149) |
| horizon     | yes    | yes         | yes             | native: `php artisan horizon` + supervisor gate |
| php-worker  | yes    | yes         | yes             | native: registry-only; queue worker |

Laradock-bridge note:

- This matrix shows the minimum expected baseline for Laradock.
- At real runtime, `laradock-bridge` can discover and show/manage all services in the active Laradock `docker-compose.yml`.
- So the Laradock column is a static minimum capability; the runtime service list comes from the compose file.

## Status Labels

- `yes`: supported
- `no`: not supported
- `opt`: optional/profile-based

## Default Toggle Policy

- In the minimal default profile, only these services default to `true`:
  - nginx(web)
  - php runtime
  - composer
  - mariadb
- Other services default to `false` and are enabled later as needed.
- Services later set to `true` via `services update` are automatically reconciled.

## Versioning

- Optional `PLUME_<SERVICE>_VERSION` env value is supported per service.
- `services status/supported --json` shows active version info per service.
- Alias resolution is supported for PHP services (`php`, `default`, alias names).

## Phase 6 Native Runtime

- For native mode, `services install/up/down/status/health/logs` command-paths work.
- For services that use ports, fallback port selection applies:
  - if the default port is taken, a free port is searched in the `+1..+50` range.
  - the selected port is written to the `services_ports_native.env` state file.
- Runtime state (`running`, `health`) is kept in `services_runtime_native.env`.

## Phase 7 Docker-Lite Runtime

- For docker-lite mode, `services install/up/down/status/health/logs` command-paths work via compose-service mapping.
- `services workspace up|down|status --mode=docker-lite` commands manage the compose workspace lifecycle.
- Docker-lite runtime state/port metadata files use the same format as native.
- Note 2026-03-10: docker-lite is in `beta-frozen` status; active development priority has shifted to native + laradock-bridge parity.

## Rule

- When a new service is added, this matrix and the `services supported` command doc are updated in the same change.
- When service custom version support is active, supported major/minor ranges are also listed in this file.
