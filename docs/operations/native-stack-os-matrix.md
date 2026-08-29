# Native Stack OS Matrix (Phase 17)

Kaynak karar: D-119. Agent kurallari: [AGENTS.md](../../AGENTS.md) §9.

## Legend

| Seviye | Anlam |
|--------|--------|
| **full** | brew/apt/dnf install + start/stop + health probe |
| **npm** | Global npm paketi + Plume PID yonetimi |
| **macOS-only** | Yalnizca Homebrew |
| **toggle** | Env/state only (Phase 17 disi) |

## Servis matrisi

| Servis | macOS (brew) | Debian/Ubuntu (apt) | RHEL/Fedora (dnf) | Health |
|--------|--------------|---------------------|-------------------|--------|
| nginx/apache/caddy | full | full | full | listen (`PLUME_WEB_PORT`) |
| mariadb | `mariadb` | `mariadb-server` | `mariadb-server` | `mysqladmin ping` (stdout yut) |
| mysql | `mysql` | `mysql-server` | `mysql-server` | `mysqladmin ping` |
| postgres | `postgresql@16` | `postgresql` | `postgresql-server` | `pg_isready` |
| redis | `redis` | `redis-server` | `redis` | `redis-cli ping` |
| memcached | `memcached` | `memcached` | `memcached` | TCP listen 11211 |
| mongodb | `mongodb-community` (tap) | WARN + manual repo | WARN | `mongosh` ping |
| rabbitmq | `rabbitmq` | `rabbitmq-server` | `rabbitmq-server` | `rabbitmq-diagnostics ping` |
| mailpit | macOS-only | — | — | HTTP 2xx/3xx |
| phpmyadmin | brew `phpmyadmin` + `php -S` | `phpmyadmin` + nginx | benzer | HTTP |
| pgadmin | pip `pgadmin4` in state venv + HTTP | pip / docker | benzer | HTTP |
| mongo_webui | npm `mongo-express` | npm | npm | HTTP |
| redis_webui | npm `redis-commander` | npm | npm | HTTP |
| horizon/supervisor | brew `supervisor` + Plume supervisord | apt `supervisor` | dnf `supervisor` | supervisorctl RUNNING (D-147) |
| php_worker | registry-only | registry-only | registry-only | `health=registry` |
| meilisearch/minio | toggle | toggle | toggle | `health=registry` (backlog) |

## Agent yukumlulukleri

- Yeni native servis PR: bu tablo + smoke (mock PATH) + `docs/commands/` guncellemesi.
- Linux smoke: mock `apt-get` + fake `systemctl` (phase12/17 pattern).
- macOS: [macos-permissions.md](./macos-permissions.md) brew onay.

## Auto-provision

`PLUME_NATIVE_SERVICE_AUTO_PROVISION=true` (default): native modda `enabled=true` servisler `services up` ile host install+start dener. Escape: `--no-provision` veya global `PLUME_NATIVE_HOST_PROVISION=false` + servis disabled.
