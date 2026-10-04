# Phase 08A - Laradock Bridge Runtime Parity

## Objective

- Safely manage existing Laradock stacks in `laradock-bridge` mode through Plume's standard service command surface.
- Goal: keep the same command contract as `native` while binding the engine side to Laradock compose/container state.

## Delivery Scope

This sub-phase covers only the first runtime parity slice.
The following commands will bind to real Laradock runtime:

- `services up <service>|all --mode=laradock-bridge`
- `services down <service>|all --mode=laradock-bridge`
- `services status [--mode=laradock-bridge]`
- `services health [service] --mode=laradock-bridge`
- `services logs <service> --mode=laradock-bridge`
- `services exec <service> --mode=laradock-bridge`
- `services containers [service] --mode=laradock-bridge`

## Non-Goals

- Redesigning the Laradock repo interior by Plume
- Creating a new compose template
- Expanding Docker-lite parity
- Native host provisioning
- TLS, secrets, backup, rollback production flows

## Runtime Source of Truth

- For `laradock-bridge`, the primary source-of-truth is live docker compose/container state.
- State env files and SQLite are cache/telemetry only.
- If live docker and state conflict, live docker wins.

## Service Mapping Baseline

In the first slice, the following service map is standardized:

| Plume Service | Laradock Compose Service |
|---|---|
| `nginx` | `nginx` |
| `apache2` | `apache2` |
| `caddy` | `caddy` |
| `php` / `php-fpm` | `php-fpm` |
| `workspace` | `workspace` |
| `composer` | `workspace` |
| `mariadb` | `mariadb` |
| `mysql` | `mysql` |
| `phpmyadmin` | `phpmyadmin` |
| `redis` | `redis` |
| `horizon` | `laravel-horizon` |
| `supervisor` | `laravel-horizon` |
| `php-worker` | `php-worker` |

Note:

- In this slice, `supervisor` is modeled as process-manager behavior inside `laravel-horizon`, not as a separate Laradock container.
- `composer` remains a `workspace` alias, not a separate container.

## Implementation Plan

### 1. Compose Discovery Normalization

- The `mode path get laradock-bridge` + `--path` + env override chain will be normalized in one place.
- Compose file resolution for Laradock will be made deterministic.
- `COMPOSE_PROJECT_NAME` and container names will be resolved directly from `.env` + compose.

### 2. Runtime Lifecycle

- `services up/down` will run real `docker compose up -d/stop` via the Laradock compose service map.
- `all` behavior will not be destructive:
  - it will only affect target services in the Plume support matrix
  - it will not target unknown services in Laradock

### 3. Status/Health/Logs

- `status`:
  - live container state will be read
  - `enabled/running/health/port/version` will be normalized
- `health`:
  - container running + healthcheck state will be read
  - if there is no healthcheck, `running=true -> healthy`, otherwise `stopped`
- `logs`:
  - `docker compose logs --tail N`
- After each read, the SQLite `services` table will be updated as cache.

### 4. Exec/Containers Hardening

- Existing `exec` and `containers` commands will be hardened with Laradock path normalization.
- The `composer` -> `workspace` alias will be preserved.
- Block behavior in `native` mode will not change.

### 5. Safe Interoperability

- `services up/down` will first run a minimal preflight similar to `services laradock check`.
- If path/compose cannot be found, fail-fast.
- Unknown service mappings will return an explicit error instead of a fallback.

## Test Plan

### Required Smokes

- `phase8_laradock_runtime_status_smoke.sh`
- `phase8_laradock_runtime_health_logs_smoke.sh`
- `phase8_laradock_runtime_up_down_smoke.sh`
- `phase8_laradock_runtime_exec_containers_smoke.sh`
- `phase8_laradock_runtime_sync_db_smoke.sh`

### Regression Gates

- existing `phase8_laradock_bootstrap_smoke.sh`
- existing `phase7_services_exec_smoke.sh`
- existing `phase7_services_containers_smoke.sh`
- native service smokes must not break

## Definition of Done

- In `laradock-bridge` mode, `up/down/status/health/logs/exec/containers` commands bind to live Laradock compose state
- state DB cache stays in sync
- unsupported/destructive behavior is not done by default
- docs are updated
- decision log entry is added

## Risks

- Laradock compose variations (`docker-compose.override`, custom compose file chain)
- Container names drifting from expectations due to `COMPOSE_PROJECT_NAME` differences
- `laravel-horizon`/`php-worker` image or service names changing in repo forks

## Immediate Next Step

- First implement `status/health/logs`.
- Then `up/down`.
- Finally `exec/containers` normalization + DB sync hardening.
