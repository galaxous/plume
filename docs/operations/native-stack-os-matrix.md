# Native Stack OS Matrix (Phase 17)

Source decision: D-119. Agent rules: [AGENTS.md](../../AGENTS.md) §9.

## Legend

| Level | Meaning |
|--------|--------|
| **full** | brew/apt/dnf install + start/stop + health probe |
| **npm** | Global npm package + Plume PID management |
| **macOS-only** | Homebrew only |
| **toggle** | Env/state only (outside Phase 17) |

## Service matrix

| Service | macOS (brew) | Debian/Ubuntu (apt) | RHEL/Fedora (dnf) | Health |
|--------|--------------|---------------------|-------------------|--------|
| nginx/apache/caddy | full | full | full | listen (`PLUME_WEB_PORT`) |
| mariadb | `mariadb` | `mariadb-server` | `mariadb-server` | `mysqladmin ping` (stdout swallowed) |
| mysql | `mysql` | `mysql-server` | `mysql-server` | `mysqladmin ping` |
| postgres | `postgresql@16` | `postgresql` | `postgresql-server` | `pg_isready` |
| redis | `redis` | `redis-server` | `redis` | `redis-cli ping` |
| memcached | `memcached` | `memcached` | `memcached` | TCP listen 11211 |
| mongodb | `mongodb-community` (tap) | WARN + manual repo | WARN | `mongosh` ping |
| rabbitmq | `rabbitmq` | `rabbitmq-server` | `rabbitmq-server` | `rabbitmq-diagnostics ping` |
| mailpit | macOS-only | — | — | HTTP 2xx/3xx |
| phpmyadmin | brew `phpmyadmin` + `php -S` | `phpmyadmin` + nginx | similar | HTTP |
| pgadmin | pip `pgadmin4` in state venv + HTTP | pip / docker | similar | HTTP |
| mongo_webui | npm `mongo-express` | npm | npm | HTTP |
| redis_webui | npm `redis-commander` | npm | npm | HTTP |
| horizon/supervisor | brew `supervisor` + system unit | apt `supervisor` + systemd | dnf `supervisor` + systemd | supervisorctl RUNNING (D-149) |
| php_worker | registry-only | registry-only | registry-only | `health=registry` |
| meilisearch/minio | toggle | toggle | toggle | `health=registry` (backlog) |

## Agent obligations

- New native service PR: this table + smoke (mock PATH) + `docs/commands/` update.
- Linux smoke: mock `apt-get` + fake `systemctl` (phase12/17 pattern).
- macOS: [macos-permissions.md](./macos-permissions.md) brew approval.

## Auto-provision

`PLUME_NATIVE_SERVICE_AUTO_PROVISION=true` (default): in native mode, `enabled=true` services attempt host install+start with `services up`. Escape: `--no-provision` or global `PLUME_NATIVE_HOST_PROVISION=false` + service disabled.
