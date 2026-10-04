# Target Architecture

## Design Principles

- Single binary/entrypoint: `plumectl`
- Mode-based engine selection: `native | docker-lite | laradock-bridge`
- Idempotent commands: repeating the same command must not have a destructive effect
- State awareness: intelligence layer for "is it installed, is it running, is the port free"
- No monolithic script: modular shell architecture via import (`source`)

## Layers

1. CLI Layer
   - Command parse
   - Mode selection
   - Output formatting

2. Config Layer
   - `plume.yml` read/validate
   - Environment override
   - Secret references (path/env)
   - Unified `.env` contract (`PLUME_*`) + mode-specific prefixes

3. State Layer
   - Runtime state (similar to `~/.config/plume/state.json`)
   - Port allocation records
   - Last health-check results

4. Engine Layer
   - NativeEngine
   - DockerLiteEngine
   - LaradockBridgeEngine

5. Service Adapters
   - install/start/stop/status/health/logs for each service
   - Package management and config file template work
   - Mode-based supported-service inventory
   - Service dependency rules (example: `horizon -> supervisor`)

6. Observability Layer
   - Health-check collector
   - Log collector/router
   - Simple metrics summary

7. Platform & Prerequisite Layer
   - OS detection (macOS/Linux)
   - Linux distro detection (apt/dnf)
   - Core dependency checks + fail-fast gate

8. Site Registry Layer
   - Central website records (`site-id`, path, domain, server, mode)
   - Server-specific config render/publish flow
   - Drift detection (registry vs system config difference)

9. Documentation & Contract Layer
   - Command-based documentation (`docs/commands/*`)
   - CLI output/exit-code contracts (`docs/contracts/*`)
   - Adapter-readiness check on every release

10. Security, Secrets & Rollback Layer
   - TLS certificate lifecycle (issue/renew/apply)
   - Secret source resolution (env/file)
   - Config apply transaction + rollback
   - Firewall/OS security preflight checks

11. Version Resolution Layer
   - Service-specific version pin/resolution
   - PHP multi-version inventory
   - Alias/default PHP switching rules

12. Laravel Lifecycle Layer
   - Project bootstrap (`composer`, `.env`, `key:generate`, `storage:link`)
   - Runtime orchestration (`queue`, `scheduler`, `horizon`, optional `octane/reverb`)
   - Deploy orchestration (`migrate`, warmup, restart, health gate, rollback)

13. Service Reconcile Layer
   - Config diff (enabled toggles) detection
   - Auto install + auto start for `false -> true` services
   - Drift and partial-failure retry policy

## Shell Modularity Contract

Recommended file layout:

- `bin/plumectl`: thin entrypoint, bootstrap + router call only
- `lib/bootstrap.sh`: strict mode, env bootstrap, import loader
- `lib/common/*.sh`: log, error, fs, process, ports
- `lib/config/*.sh`: yaml parse/validate (parser wiring later)
- `lib/commands/*.sh`: command handlers (`cmd_status`, `cmd_services_up`, etc.)
- `lib/engines/*.sh`: `engine_native_*`, `engine_docker_lite_*`, `engine_laradock_bridge_*`
- `lib/services/*.sh`: service adapters (`svc_mysql_*`, `svc_redis_*`)
- `lib/sites/*.sh`: site registry, prompt, server config publish, hosts sync
- `lib/docs/*.sh` (optional): doc-sync helper scripts

Import rules:

- All modules must be compatible with `#!/usr/bin/env bash` and `set -euo pipefail`
- Import must only happen through bootstrap (scattered `source` is forbidden)
- Function names must start with a namespace:
  - `cmd_*`, `engine_*`, `svc_*`, `port_*`, `cfg_*`, `log_*`
- Modules should use explicit parameters + return codes instead of global variables
- For testability, commands should delegate side-effect steps to adapter functions

## Website Onboarding Design

Target commands:

- `plumectl site add` (interactive)
- `plumectl site add --path=... --domain=... --server=nginx` (non-interactive)
- `plumectl site link <site-id>` (writes registry record into active server config)
- `plumectl site check <site-id>` (path + config + port + health validation)

Interactive prompt steps (`site add`):

1. Ask for project path
2. Check whether the path is real and a web root exists (`public/`, static root, custom root)
3. Ask for web server choice (`nginx|apache2|caddy`)
4. Ask for domain/alias (`myapp.test`, `api.myapp.test`)
5. Run conflict checks (same domain, same path, port/service down)
6. Write the registry record
7. Generate and activate the server config file
8. Update hosts if needed + server reload + result report
9. If it is a Laravel project, suggest/apply bootstrap steps

Central registry and path resolution:

- Works independently of CWD; every site record keeps an absolute path
- Default registry locations:
  - Local: `~/.config/plumectl/sites/`
  - Server: `/etc/plume/sites/`
- One `website.yaml` per project, `index.yaml` for the global index
- Commands treat the path in the registry as the source of truth instead of `--cwd`

## Documentation Requirement

- Docs under `docs/commands` are mandatory for every new command and flag
- On behavior changes, the command doc and contract file must be updated in the same change
- Because CLI outputs will be parsed on the adapter side:
  - Stable field names on success
  - Stable error code + message schema on failure

## Privilege Model (Privilege Split)

- Sudo/root required:
  - install, uninstall, update, service package install, system config write
- Runtime commands that do not require root:
  - `status`, `health`, `logs`, `services up/down` (non-root whenever possible)
- Every command first runs a privilege preflight check and gives clear guidance if missing

## Horizon & Supervisor Rule

- Laravel Horizon is managed with supervisor in native mode.
- If `horizon.enabled=true`:
  - `supervisor` prereq check is required
  - supervisor config/template publish is required
  - `plumectl services up horizon` must start the process through supervisor
- In docker-lite mode, a supervisor or equivalent process manager strategy for Horizon is documented.

## Secrets & TLS

- Secret sources:
  - environment variables
  - encrypted/plain file reference (per policy)
- TLS:
  - local: self-signed/mkcert-like flow
  - production: ACME/letsencrypt-like automation
  - for docker-lite, a dedicated cert-helper container if needed

## Rollback Model

- Config apply steps run in a transaction-like way:
  1. take a backup first
  2. write the new config
  3. validate/reload
  4. on failure, automatically restore the previous config
- Write the rollback result to the log and status layers

## Laravel Project Lifecycle

- Bootstrap:
  - `composer install`
  - create/merge `.env`
  - `php artisan key:generate`
  - `php artisan storage:link`
  - optional: `php artisan migrate --force`, `db:seed`, `config:cache`, `route:cache`
- Runtime:
  - scheduler: cron/systemd timer
  - queue worker: supervisor/system service
  - horizon: supervisor required
  - optional: octane/reverb process manager integration
- Deploy:
  - preflight checks
  - code/artifact switch
  - migration gate
  - queue/horizon recycle
  - post-deploy health verification
  - rollback on failure

## OS Split and Prereq Gate

Platform functions:

- `platform_detect_os` -> `macos | linux`
- `platform_detect_pkg_manager` -> `brew | apt | dnf | unknown`
- `platform_detect_init` -> `launchd | systemd | unknown`

Core prereq policy:

- Every command runs the related profile prereq check before execution
- If a required dependency is missing, the command stops with `non-zero`
- Output includes:
  - missing package list
  - automatic/manual install command suggestion (by OS)
  - "retry" step

Example prereq profiles:

- `base`: bash, sed, awk, grep, cut, xargs, tar, gzip, curl
- `native-install`: base + sudo + package-manager(brew/apt/dnf)
- `git-ops`: base + git + ssh
- `docker-lite`: base + docker + docker compose
- `laradock-bridge`: docker-lite + existing laradock path validation

## Environment Contract

- All settings are resolved together from `.env` and yaml.
- Precedence:
  1. CLI flags
  2. `.env` (`PLUME_*`)
  3. yaml config
  4. built-in defaults
- Mode-specific prefixes:
  - native: `PLUME_NATIVE_*`
  - docker-lite: `PLUME_DOCKER_LITE_*`
  - laradock-bridge: `PLUME_LARADOCK_*`

## Service Versioning & PHP Alias

- Version selection is supported per service (example: mysql 8.0, redis 7, mariadb 11).
- Version selection precedence:
  1. CLI `--version`
  2. project yaml
  3. global default
- For PHP:
  - Multiple versions can coexist
  - The `php` default alias points to the active version
  - Versioned aliases (`php81`, `php82`, `php83`) are created
  - Composer and PHP-FPM binding stay aligned with the selected active version

## Service Default Profile & Reconcile

- Default profile: `minimal-default`
  - enabled: nginx(web), php, composer, mariadb
  - disabled: all other optional services
- `services update` behavior:
  1. compare current state + config
  2. find `false -> true` services
  3. prereq check
  4. install + start
  5. write results to state/log

## Example Command Tree

- `plumectl mode use <mode>`
- `plumectl project init`
- `plumectl php list|install|use|alias`
- `plumectl services install [name|all]`
- `plumectl services up [name|all]`
- `plumectl services down [name|all]`
- `plumectl services supported [--mode=...]`
- `plumectl status`
- `plumectl logs [service]`
- `plumectl health [service|all]`
- `plumectl doctor [--deep]`

## Port Intelligence Strategy

- Priority list per service:
  - example mysql: `3306, 3307, 3308`
- Algorithm:
  - Find a free port -> allocate -> write to state
  - If occupancy changes, reconcile again
- Output:
  - Deterministic report to the user:
    - "mysql: requested 3306, allocated 3307 (3306 occupied by process X)"

## Security and Operations

- Steps that need root/sudo will be clearly separated
- Changes to apply will be shown beforehand via `dry-run` mode
- In production mode, critical steps will be protected by a confirm gate

## Naming Policy

- Product/brand: `Plume`
- Official CLI binary: `plumectl`
- Optional shell alias: `plume -> plumectl`
- Repository naming: `laravel-plume`
- Package naming:
  - Packagist: `<vendor>/laravel-plume`
  - Homebrew formula: `laravel-plume` or `plumectl`
