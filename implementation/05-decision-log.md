# Decision Log (ADR-Lite)

This file records technical decisions taken across phases.

## 2026-10-03 - D-158 - No interactive sudo password in noninteractive / smoke

- Status: accepted
- Decision:
  - `plume_sites_nginx_run_elevated`: try `sudo -n` first; in noninteractive there is **no** password prompt (fail-soft return 1).
  - After an interactive confirm, a one-time password sudo is allowed.
  - `PLUME_NATIVE_NGINX_FORCE_UNPRIVILEGED_RELOAD=true`: skip host root nginx elevated detection in hermetic/fake nginx smokes.
  - Smoke suite `PLUME_NONINTERACTIVE=1` + `PLUME_INTERACTIVE=false` (`run_smoke_suite.sh`).
  - Reload/sync-config smoke: temp `HOME` (so an empty `PLUME_NATIVE_NGINX_MAIN_CONF=` override in real `~/.config/plume/.env` cannot clobber it).
- Rationale:
  - `confirm_sudo` returned `0` in noninteractive; then interactive `sudo` Password: blocked the suite.
  - An empty `MAIN_CONF=` .env line cleared the smoke override after source → host `/opt/homebrew/etc/nginx/nginx.conf` patch.
- Impact:
  - `lib/common/sites.sh`; phase11/12 hermetic HOME/PATH/ENSURE/FORCE_UNPRIVILEGED flags.

## 2026-10-03 - D-157 - plume_info on stderr (parseable stdout)

- Status: accepted
- Decision:
  - `plume_info` → `stderr` (same as `plume_warn` / `plume_err`).
  - `stdout` is only the primary payload (e.g. `site add` site id).
  - Contract: [cli-output-contract.md](../docs/contracts/cli-output-contract.md).
  - Hermetic site smoke: `PLUME_NATIVE_NGINX_ENSURE_ON_PUBLISH=false`; phase4 `site publish` without `--reload` (no host brew/sudo).
  - Smokes that assert INFO/hooks capture with `2>&1` (`start hook: … [version=…]` is on stderr).
- Rationale:
  - D-151 ensure `[INFO]` lines mixed into `site add` stdout; `SITE_ID="$(…)"` + awk multiline broke; release smoke `phase4-site` failed.
- Impact:
  - `lib/common/log.sh`, phase4/phase6/phase11 INFO-grep smokes, cli-output-contract, ai-assisted-development.

## 2026-10-02 - D-156 - Manual Release pre-tag VERSION + Formula version/url sync

- Status: accepted
- Decision:
  - Single workflow: [manual-release.yml](../.github/workflows/manual-release.yml) — smoke → tag → sync → force-tag → Release.
  - Sync script: [packaging/homebrew/sync-release-version.sh](../packaging/homebrew/sync-release-version.sh) writes `VERSION` + both Homebrew formula `version`/`url` in the same commit.
  - `sha256` is not touched in sync (tarball hash after frozen tag; `:no_check` or `main` bump without retag).
  - Compatible with galaxous/github-workflows `reusable-manual-release` VERSION sync model; Formula extension is Plume-side (reusable has no multi-file/formula hook yet).
- Rationale:
  - Manual formula sync is error-prone; tag contents must stay aligned with `plumectl version` + brew `url`/`version`.
- Impact:
  - Maintainer checklist simplified; phase28 smoke sync script + formula↔VERSION assert.

## 2026-09-29 - D-155 - Pinned VERSION + Homebrew/Packagist release (Herd P3)

- Status: accepted
- Decision:
  - Repo `VERSION` is the single source; `plumectl version` / `--json version` reads it.
  - Publish: [release.md](../docs/operations/release.md) + [install.md](../docs/operations/install.md).
  - Manual Release workflow gates on `./tests/run_smoke_suite.sh --release`.
  - Homebrew formula: `packaging/homebrew/plumectl.rb` + `Formula/plumectl.rb` (`plumectl` / alias `plume`).
  - Packagist: `galaxous/laravel-plume` (`composer.json`, `bin/plumectl`); auto-update = `brew upgrade` / `composer global update`.
  - Linux: distro-agnostic `packaging/linux/install.sh` (`PLUME_REF`, `PREFIX`); no `.deb`/`.rpm`.
  - Staged install: [install.md](../docs/operations/install.md) A–H (maintainer → macOS → Debian/Ubuntu → RHEL/Fedora → other Linux).
  - `plumectl self-update` intentionally absent.
  - Version bump CI: D-156 (VERSION + formula version/url).
- Rationale:
  - User priority was P4 then P3; hard-coded version + clone/`make install` alone is insufficient; Linux distros must not be skipped.
- Impact:
  - Phase 28 done, `VERSION`, composer.json, Formula, linux install.sh, phase28 smoke, manual-release.yml.

## 2026-09-27 - D-154 - Composer + Node workspace CLI (Herd parity P4)

- Status: accepted
- Decision:
  - New commands: `plumectl composer|npm|node` (`lib/commands/workspace.sh`).
  - Project path: `--path` / `--site` / cwd site match / cwd / mode path.
  - Native Composer: site or default PHP is prepended to `PATH` (`COMPOSER_PHP` when possible).
  - docker-lite / laradock-bridge: `workspace` container `exec -T`.
  - Binary override: `PLUME_COMPOSER_BIN`, `PLUME_NPM_BIN`, `PLUME_NODE_BIN`.
  - Priority: P4 first, then P3 release; P1 Docker-lite and P2 meilisearch/minio deferred (user).
- Rationale:
  - Open Herd parity item; `project init` is bootstrap only — there was no daily `composer`/`npm` surface.
- Impact:
  - Phase 27, [workspace.md](../docs/commands/workspace.md), `phase27_workspace_composer_npm_smoke.sh`.

## 2026-09-17 - D-153 - Homebrew supervisor drop-in: etc/supervisor.d/*.ini

- Status: accepted
- Decision:
  - Homebrew `supervisord.conf` include: `/opt/homebrew/etc/supervisor.d/*.ini` (not formula `opt/supervisor/etc/.../*.conf`).
  - Plume program path/ext: derived from the main conf `[include] files=` line; brew default ext=`ini`.
  - Stale `host.env` `supervisor_programs_dir=.../opt/supervisor/etc/supervisor.d` is ignored; old `.conf` files are cleaned on write.
- Rationale:
  - Horizon conf was written but supervisord did not see the program (`ERROR no such process`); Horizon stayed stopped even when Redis was healthy.
- Impact:
  - `native_supervisor.sh`, `phase26_supervisor_brew_ini_smoke.sh`, docs services-supervisor/horizon.

## 2026-09-17 - D-152 - Horizon/supervisor diagnose via Plume only

- Status: accepted
- Decision:
  - Do not tell the user to run `supervisorctl` / `brew services`; diagnosis and remediation are `plumectl` commands only.
  - If `services up horizon` health fails, print program status + worker log tail + `doctor`/`logs`/`restart` hints.
  - `services logs horizon [--site=]` reads native per-site `horizon-<site-id>.log` files.
  - If the drop-in is not loaded yet, Plume silently restarts the system supervisor (brew message is hidden).
  - `doctor supervisor` horizon WARN/FAIL lines include plumectl remediation.
- Rationale:
  - On Horizon stopped/health fail, users were pushed to brew/supervisorctl; the product promise is plumectl-only.
- Impact:
  - `native_horizon.sh`, `native_supervisor.sh`, `registry.sh` logs, doctor, [services-horizon.md](../docs/commands/services-horizon.md).

## 2026-09-15 - D-151 - Native nginx HTTP port 80 guarantee (macOS + Linux)

- Status: accepted
- Decision:
  - Default `PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=true`, target `PLUME_NATIVE_NGINX_HTTP_PORT=80`.
  - Site snippet render: when manage is on, the *desired* port is used (writes `listen 80` even if main conf is still 8080).
  - `plumectl services web ensure`: main conf sync + privileged bind (sudo/brew|systemctl) + republish all native nginx sites.
  - `site publish` / `services up|restart web`: automatic ensure (`PLUME_NATIVE_NGINX_ENSURE_ON_PUBLISH` / `_ON_WEB_UP`, default true).
  - macOS Homebrew and Linux `/etc/nginx/nginx.conf` paths; elevated restart for port < 1024.
- Rationale:
  - Users expect `http://site.test` (no port); brew 8080 + opt-in sync UX conflicts with Plume's goal.
- Impact:
  - `native_web_nginx_config.sh`, `services web ensure`, site publish hook, docs/commands/services-web.md.

## 2026-08-30 - D-150 - Per-site native Horizon supervisor programs

- Status: accepted
- Decision:
  - Separate supervisor program per Plume site record: `plume-horizon-<site-id>`; project path from site `path`, PHP from site `php_version`.
  - Site record `horizon: true|false`; CLI: `site add|update --horizon` / `--no-horizon`.
  - `services up|down horizon [--site=<site-id>]`: all horizon-enabled sites or a single site.
  - Legacy single program (`plume-horizon` + `PLUME_HORIZON_PATH`) is only a fallback when no horizon-enabled site exists.
  - `doctor supervisor`: per-site `horizon-program:<site-id>` lines.
- Rationale:
  - Global `PLUME_HORIZON_PATH` is insufficient in multi-project environments; Herd/Laradock expect a per-project worker.
- Impact:
  - `lib/services/native_horizon.sh`, `site` command, `phase24_per_site_horizon_smoke.sh`, [services-horizon.md](../docs/commands/services-horizon.md).

## 2026-08-30 - D-149 - System-primary supervisor + doctor + upgrade --force

- Status: accepted
- Decision:
  - Native supervisor runtime: system-primary (`brew services supervisor` / `systemctl`), D-147 Plume-owned supervisord is legacy; migrate with `services supervisor upgrade --force --yes`.
  - `doctor supervisor`: host.env cache, binary/unit/schema/registry/horizon checks; REMEDIATION line.
  - First upgrade with `--force` closed: `--force` + `--yes` required; `--dry-run` plan.
  - `services supervisor program add`: template + interactive placeholder questions; conf OS drop-in + registry.
  - `host.env`: persist `supervisor_*` fields (`plume_host_profile_set_value`).
- Rationale:
  - User wanted system supervisor + full-privilege conf add; D-147 state-dir daemon is not operational.
- Impact:
  - `lib/services/native_supervisor.sh`, `doctor supervisor`, `services supervisor`, `phase-23.md`, D-147 partial supersede.

## 2026-08-18 - D-148 - Native Redis keeps configured port if already listening

- Status: accepted
- Decision:
  - `services up redis` searches +1 if preferred port (`6379`) is held by another process; if the listener is already `redis-server`, it does not change the port.
- Rationale:
  - During `sync-config --reload` or while existing brew Redis held 6379, `up` moved to 6380; Laravel `REDIS_PORT=6379` broke.
- Impact:
  - `plume_service_allocate_explicit_port`, [services-redis.md](../docs/commands/services-redis.md).

## 2026-08-18 - D-147 - Native supervisor + Horizon host worker

- Status: accepted
- Decision:
  - `supervisor` / `horizon` native driver: brew/apt `supervisor` binary; Plume-owned `supervisord` (state dir + detach, D-140). Homebrew `brew services supervisor` is not used.
  - Horizon program: `php artisan horizon` (`PLUME_HORIZON_PATH` or first site artisan).
  - `health=healthy` only when supervisorctl RUNNING/STARTING; `php_worker` remains registry-only.
  - Mock/smoke: `PLUME_NATIVE_HOST_INSTALL_DRIVER=mock` — no brew install.
- Rationale:
  - After D-146 honesty, the user wants a real worker; Laravel `QUEUE_CONNECTION=redis` should complete with the native stack.
- Impact:
  - `lib/services/native_horizon.sh`, drivers, `phase-22.md`, `docs/commands/services-horizon.md`.

## 2026-08-12 - D-146 - Native queue/search honesty (registry-only)

- Status: accepted
- Decision:
  - `horizon` / `supervisor` / `php_worker`: native `up` exit 0 + WARN; `health=registry` (no host daemon). No fail-fast — existing phase6/11 smokes expect `up` success with supervisor.
  - `meilisearch` / `minio`: same registry-only; WARN `toggle-only`; native driver backlog (Herd parity).
  - Real brew supervisor / meilisearch/minio host driver in a later phase.
- Rationale:
  - `up @core` (old) showed horizon as running; half-honest UX. Docker-lite/laradock is the correct path for a real worker.
- Impact:
  - `native_host_provision.sh`, `registry.sh` start warn, `phase-21.md`, `phase21_queue_honesty_smoke.sh`.

## 2026-08-12 - D-145 - Native memcached + cache/broker contract

- Status: accepted
- Decision:
  - memcached: brew/apt/dnf driver, port 11211, credentials `127.0.0.1`, member of `@cache`.
  - mongodb / rabbitmq / mongo_webui / redis_webui are validated with the same native-service-contract (D-144).
- Rationale:
  - Laravel cache/session/queue broker optionals want Laradock container UX; memcached was toggle-only in Phase 17.
- Impact:
  - `native_host_service_drivers.sh`, `phase-20.md`, `docs/commands/services-memcached.md`.

## 2026-08-12 - D-144 - Native service contract (Laradock-container UX)

- Status: accepted
- Decision:
  - Every native service: enable → `services up` → live health → credentials/url; TCP host `127.0.0.1`.
  - `@core`: php, composer, web, DB engines, redis, phpmyadmin, pgadmin, mailpit — **no queue**.
  - Status: live probe; stale PID / dead brew → `stopped` (no lying `starting`). Live HTTP PID → `starting`.
  - `services use mariadb|mysql|postgres`: XOR + phpmyadmin/pgadmin mapping + `database.engine` (mysql-family).
  - Docker-lite unfreeze is sequenced **behind** this native P0.
- Rationale:
  - Lessons from D-138..D-143 (detach, leak, loopback, stdout) must spread to all critical services.
- Impact:
  - [native-service-contract.md](../docs/operations/native-service-contract.md), `phase-19.md`, `cmd_services_use`.

## 2026-08-09 - D-143 - mysqladmin ping without --batch (MariaDB 12 client)

- Status: accepted
- Decision:
  - Native mariadb/mysql health: `mysqladmin ping ... --silent` with stdout+stderr → `/dev/null` (no `--batch`).
  - MariaDB 12 client: `--batch` unknown; `--silent` still prints `mysqld is alive` → must redirect stdout or status HEALTH column corrupts.
- Rationale:
  - Probe fail / `HEALTH=mysqld is alive` / status parse break.
- Impact:
  - `lib/services/native_host_service_drivers.sh`.

## 2026-08-09 - D-142 - Native phpMyAdmin connect host is 127.0.0.1

- Status: accepted
- Decision:
  - `config.inc.php` server `host` = `127.0.0.1`; `verbose` = `mariadb|mysql` (dropdown label).
  - `/etc/hosts` alias is optional; login does not break if it cannot be written without sudo.
  - Credentials file for phpmyadmin is rewritten (enabled engines only).
- Rationale:
  - Hosts sync skip → `getaddrinfo for mariadb failed`; users could not connect even with correct credentials.
- Impact:
  - `native_phpmyadmin_config.sh`, drivers credentials, smoke, docs.

## 2026-08-09 - D-141 - phpMyAdmin smoke must not leak host :8081

- Status: accepted
- Decision:
  - Mock `php -S` shim: `exec python3 -m http.server --bind 127.0.0.1` (PID = listener; no orphan nohup).
  - Smoke cleanup: kill phpmyadmin pid + stray `http.server.*8081` on host.
- Rationale:
  - Old smoke left `nohup python3 -m http.server 8081` on the host; after temp docroot deletion Python returned 404; real phpMyAdmin moved to 8082 when busy; user opening `localhost:8081` got 404.
- Impact:
  - `tests/phase17_native_phpmyadmin_smoke.sh`, `tests/phase11_native_core_services_parity_smoke.sh`.

## 2026-08-09 - D-140 - Detach native HTTP daemons + stale PID status

- Status: accepted
- Decision:
  - `plume_native_detach_daemon`: double-fork + `setsid` (Python); parent shell/process-group kill cannot kill the daemon.
  - pgadmin / phpmyadmin / npm webui start use this helper.
  - `plume_service_health`: for managed HTTP services, probe fail + dead PID → `running=false` + `stopped` (no false "starting").
  - HTTP probe: accept 2xx/3xx (http_code instead of `curl -sf`).
- Rationale:
  - Agent/terminal shell teardown was killing `nohup` pgadmin PID; status showed `running=true` / `starting` + browser ERR_CONNECTION_REFUSED.
- Impact:
  - `native_host_service_drivers.sh`, `native_pgadmin.sh`, `native_phpmyadmin_config.sh`, `registry.sh`.

## 2026-08-07 - D-139 - pgAdmin namespace package path + writable DATA_DIR

- Status: accepted
- Decision:
  - `pgadmin4.__file__` is `None` in a namespace package; package path is `pgadmin4.__path__[0]` (+ site-packages fallback).
  - `config_local.py`: `DATA_DIR` / `SQLITE_PATH` / `LOG_FILE` → `state/native/pgadmin/data` (not `/var/lib/pgadmin`).
  - After start, wait for HTTP ready (first boot is slow); skip pip again in an existing venv.
- Rationale:
  - Install pip OK but `package not found`; start hit `/var/lib/pgadmin` Permission denied → running=false / health=stopped.
- Impact:
  - `lib/services/native_pgadmin.sh`.

## 2026-08-07 - D-138 - Native pgAdmin (Laradock pgadmin parity)

- Status: accepted
- Decision:
  - New registry service `pgadmin`: PostgreSQL web UI (phpMyAdmin counterpart for MySQL-family).
  - Install: `state/native/pgadmin/venv` + `pip install pgadmin4` (not system cask/desktop; HTTP PID management).
  - Env uses Laradock names: `PGADMIN_ENABLED`, `PGADMIN_PORT=5050`, `PGADMIN_DEFAULT_EMAIL`, `PGADMIN_DEFAULT_PASSWORD`.
  - Dependency: `postgres` enabled; added to `@db` group.
  - Mock driver: hermetic stub binary (no real pip).
- Rationale:
  - User wants to manage Postgres with a UI like phpMyAdmin; Laradock has `pgadmin`, Plume native did not.
- Impact:
  - `lib/services/native_pgadmin.sh`, drivers/registry/services CLI, docs, `phase18_native_pgadmin_smoke.sh`, phase-18.

## 2026-08-07 - D-137 - Mock MariaDB include only when MAIN_CONF overridden

- Status: accepted
- Decision:
  - Mock `mariadb`/`mysql` sync: `!include` only when `PLUME_NATIVE_MARIADB_MAIN_CONF` is set (hermetic temp file).
  - Real Homebrew `my.cnf` is not modified during the mock lifecycle.
- Rationale:
  - D-134 mock include skip: `phase17-native-db-broker-config` `[FAIL] mariadb include`.
- Impact:
  - `lib/services/native_db_broker_config.sh`.

## 2026-08-07 - D-136 - Hosts sync never uses interactive sudo

- Status: accepted
- Decision:
  - `plume_fs_copy_no_tty`: writable `cp` or `sudo -n cp` (no tty Password:).
  - `plume_native_db_hosts_sync` + site hosts add/remove use this helper.
  - Smoke: `PLUME_NATIVE_DB_HOSTS_SYNC=false` (phase11).
- Rationale:
  - Release smoke `phase11-native-core-services-parity`: after mariadb up, `sudo cp /etc/hosts` interactive Password prompt (stderr redirect is not enough; /dev/tty).
- Impact:
  - `lib/common/os.sh`, `lib/services/native_db_hosts.sh`, `lib/common/sites.sh`, `tests/phase11_native_core_services_parity_smoke.sh`.

## 2026-08-07 - D-135 - Mailpit native health probe (mock + HTTP)

- Status: accepted
- Decision:
  - `plume_native_driver_default_port` mailpit: `PLUME_MAILPIT_PORT` (8025).
  - Health probe: allocated port (`plume_service_effective_port`) + curl.
  - `phase12-native-host-provision-mailpit` smoke: mock `curl` (8025) + mock brew.
- Rationale:
  - Release smoke: `services up mailpit` exit 2 — health probe `return 1` (mailpit outside npm/phpmyadmin path).
- Impact:
  - `lib/services/native_host_service_drivers.sh`, `tests/phase12_native_host_provision_mailpit_smoke.sh`.

## 2026-08-07 - D-134 - MariaDB root bootstrap never prompts on tty

- Status: accepted
- Decision:
  - `plume_native_mariadb_apply_root_password`: passwordless TCP `mysql` attempt removed (CI/smoke hangs on tty `Password:`).
  - Socket auth (Homebrew default) then `--batch` ALTER USER; on failure, skip silently.
  - `mysqladmin` health probe: `--batch` + `</dev/null`; if no password, socket ping; no passwordless TCP.
  - Mock driver config sync does not write the host `my.cnf` file.
  - Smoke suite: `PLUME_NONINTERACTIVE=1` default; phase11 DB mock got a `mysql` shim.
- Rationale:
  - Release smoke `phase11-native-core-services-parity`: interactive `Password:` prompt after real brew mariadb.
- Impact:
  - `lib/services/native_db_broker_config.sh`, `lib/services/native_host_service_drivers.sh`, `tests/run_smoke_suite.sh`, `tests/phase11_native_core_services_parity_smoke.sh`.

## 2026-08-07 - D-133 - Phase11 DB parity smokes use hermetic mock driver

- Status: accepted
- Decision:
  - `phase11-native-core-services-parity` mariadb/mysql/phpmyadmin steps run with mock brew + mysqladmin/php (`PATH=${MOCK_BIN}:/usr/bin:/bin`).
  - php-fpm and web driver steps remain real host integration; SQL engines are mocked due to brew single-formula limits.
  - Invalid-engine smoke: `PMA_ARBITRARY=0` (engine validation is skipped when default is `1`).
- Rationale:
  - Release smoke: `mysql start native` fail — host only has `mariadb` formula, `brew services start mysql` + health probe exit 2.
- Impact:
  - `tests/phase11_native_core_services_parity_smoke.sh`.

## 2026-08-06 - D-132 - Native registry-only services skip health gate

- Status: accepted
- Decision:
  - `horizon`, `supervisor`, `php_worker` have no brew/npm host driver in native mode; `services up` only writes registry/runtime records.
  - D-128 health gate runs only for `plume_native_host_runtime_managed` services; probe is skipped for `horizon`/`supervisor`/`php_worker` registry-only list.
  - `plume_service_health`: registry-only -> `registry`; `php`/`composer` running -> `healthy` (outside host driver, separate lifecycle).
- Rationale:
  - `phase6-service-update-path` smoke: `horizon starts when supervisor enabled` exit 2 (probe fail) after D-128.
- Impact:
  - `lib/services/native_host_provision.sh`, `lib/services/registry.sh`.

## 2026-08-06 - D-131 - Env-file load respects Laradock alias pairs

- Status: accepted
- Decision:
  - `plume_load_env` preservation: if the env file defines one end of an alias pair (`REDIS_ENABLED` or `PLUME_REDIS_ENABLED`), the other end is not preserved.
  - After env source: if the file only defines `PLUME_*`, the short name is synced to it (so stale `REDIS_ENABLED=false` left from defaults/manifest does not win on inward sync).
  - Added `plume_env_laradock_plume_to_short`.
- Rationale:
  - After D-130, writing only `PLUME_REDIS_ENABLED=true` via `--env-file` preserved a previously exported `REDIS_ENABLED=false`; inward alias made the short name win.
- Impact:
  - `lib/common/env.sh`, `lib/common/stack_service_env.sh`, `docs/operations/env-contract.md`.

## 2026-08-06 - D-130 - Laradock-style env names (config canonical)

- Status: accepted
- Decision:
  - `.env.example`, `services.yml`, user `.env`: removed `PLUME_` prefix for stack service toggle/port/credential (examples `REDIS_ENABLED`, `MARIADB_PORT`).
  - `plume_env_apply_laradock_aliases_*` (`stack_service_env.sh`): outward (defaults→short) → manifest → refresh (PLUME→short) → `.env` → inward (short→PLUME).
  - `services.yml` `${VAR}`: Laradock-style short names (example `${REDIS_ENABLED}`); old `${PLUME_*}` remains backward compatible.
  - Plume-specific keys (`PLUME_STATE_DIR`, `PLUME_MODE`, native driver settings) keep the `PLUME_` prefix.
- Rationale:
  - Laradock parity; familiar naming in config files; minimize runtime code change (alias layer).
- Impact:
  - `stack_service_env.sh`, `env.sh`, `bootstrap.sh`, `.env.example`, `templates/services.yml.example`, docs, smoke.

## 2026-08-06 - D-129 - Native allocated port export + health probe retry

- Status: accepted
- Decision:
  - `plume_service_start_native`: after allocate, export `PLUME_*_PORT` (docker-lite parity); if port changed and config-manage is on, reload; health probe 3 attempts (reload + 1s wait).
  - Explicit `services up <svc>`: even if `provision_service_wants` is false, run `plume_native_host_start_service` for supported services.
  - Redis config/health: `plume_service_effective_port` (allocated port preferred).
  - `services.yml` template: block YAML + quoted `${PLUME_*}` (IDE YAML parser compatibility).
- Rationale:
  - D-128 health gate: 6379 busy → allocate 6380 but probe/config still 6379; fail without brew restart.
- Impact:
  - `registry.sh`, `native_redis_config.sh`, template, docs, phase11 smoke hermetic skip.

## 2026-08-05 - D-128 - Native DB status probe, manifest `${VAR}`, brew dual-engine guard

- Status: accepted
- Decision:
  - `plume_service_start_native`: `running=true` only after successful start + `plume_native_host_health_probe` (mysqladmin stdout /dev/null).
  - `plume_service_status` (native): health via `plume_service_health`; stale `running` flag alone does not show `healthy`.
  - Manifest loader: `${PLUME_*}` placeholder interpolation (after defaults, before `.env`); `.env` wins.
  - Native brew: both `PLUME_MARIADB_ENABLED` + `PLUME_MYSQL_ENABLED` → manifest warning, start/provision error.
  - `database.engine` is a single native brew engine; phpMyAdmin lists only operational engines (existing).
- Rationale:
  - `services status mysql` false-positive `running healthy` when brew not installed; Laradock-style manifest discoverability; mariadb/mysql brew conflict.
- Impact:
  - `registry.sh`, `services_manifest.sh`, `native_db_hosts.sh`, `templates/services.yml.example`, docs, smoke.

## 2026-08-05 - D-127 - Native phpMyAdmin multi-server (mariadb|mysql + hosts)

- Status: accepted
- Decision:
  - phpMyAdmin server record per active engine: `verbose`/`host`=`mariadb|mysql`, port=`PLUME_*_PORT`.
  - `PLUME_NATIVE_DB_HOSTS_SYNC`: `/etc/hosts` → `127.0.0.1 mariadb mysql` (Laradock hostname parity).
  - Default `PLUME_MYSQL_PORT=3307` (avoid conflict with mariadb 3306).
  - Login: dropdown or Server field `mariadb`/`mysql` + user/password.
- Rationale:
  - Laradock has two separate containers and docker network hostnames; native needs different ports + hosts aliases for the same UX.
- Impact:
  - `native_phpmyadmin_config.sh`, `native_db_hosts.sh`, drivers, defaults, smoke, docs.

## 2026-08-05 - D-126 - phpMyAdmin Laradock arbitrary server parity

- Status: accepted
- Decision:
  - When `PMA_ARBITRARY=1` (default), native `config.inc.php` does not write fixed `host`/`port`; they are entered in the Server login form (like Laradock).
  - `PMA_DB_ENGINE` is optional in native + arbitrary mode; only for docker-lite `depends_on` and `PMA_ARBITRARY=0` fixed target.
  - Native login Server: `127.0.0.1`; docker-lite: `mariadb` or `mysql` container hostname.
- Rationale:
  - Laradock login UX: Server + user + password; `PMA_DB_ENGINE` is a compose dependency, not phpMyAdmin config.
- Impact:
  - `native_phpmyadmin_config.sh`, `registry.sh`, docs, smoke, `.env.example`.

## 2026-08-05 - D-125 - Native phpMyAdmin cookie auth (login form)

- Status: accepted
- Decision:
  - Native `config.inc.php` default `PMA_AUTH_TYPE=cookie`; user enters the MariaDB password in the login form.
  - `PMA_AUTH_TYPE=config` opt-in: `PMA_USER`/`PMA_PASSWORD` written to config (Laradock/docker auto-login parity).
  - `services credentials phpmyadmin` still returns DB hints; password is not embedded in config (cookie mode).
- Rationale:
  - `auth_type=config` opened a session on native 8081 without asking for a password; not the expected local-dev UX.
- Impact:
  - `native_phpmyadmin_config.sh`, smoke, `.env.example`, `services-phpmyadmin.md`.

## 2026-08-05 - D-124 - Native phpMyAdmin (brew + PMA config.inc.php)

- Status: accepted
- Decision:
  - macOS: `brew install phpmyadmin`; npm path removed.
  - `PMA_*` / `PLUME_PHPMYADMIN_*` → `state/native/phpmyadmin/htdocs/config.inc.php`.
  - `php -S 127.0.0.1:<port>` PID management; `services restart phpmyadmin` config sync + restart.
  - Smoke: `phase17_native_phpmyadmin_smoke.sh`; docs: `services-phpmyadmin.md`.
- Rationale:
  - Native 8081 was unreachable: empty docroot + wrong npm install path.
- Impact:
  - `native_phpmyadmin_config.sh`, drivers, services credentials, tests, docs.

## 2026-08-05 - D-123 - Native DB/Broker Config Management (MariaDB, Postgres, MongoDB, RabbitMQ)

- Status: accepted
- Decision:
  - Redis model extended: `PLUME_*` → plume include/block + automatic sync on `services restart <svc>`.
  - Services: mariadb, mysql, postgres, mongodb, rabbitmq; toggle: `PLUME_NATIVE_*_MANAGE_CONFIG=true` (default).
  - Shared helper: `native_stack_config_common.sh`; driver: `native_db_broker_config.sh`.
  - Runtime password/user: best-effort SQL/shell after restart (`ALTER USER`, `mongosh`, `rabbitmqctl`).
  - Smoke: `phase17_native_stack_db_broker_config_smoke.sh`.
- Rationale:
  - User changes `.env` → `services restart <svc>` is enough; no manual brew config edits.
- Impact:
  - drivers, defaults, stack_service_env, tests, docs.

## 2026-08-05 - D-122 - Native Redis Config Management

- Status: accepted
- Decision:
  - `PLUME_NATIVE_REDIS_MANAGE_CONFIG=true` (default): `PLUME_REDIS_PORT`, `PLUME_REDIS_PASSWORD`, `PLUME_NATIVE_REDIS_BIND` → `state/native/redis/plume-redis.conf` + system `redis.conf` include.
  - `services redis sync-config [--reload|--dry-run]`; `install|up|restart redis` automatic sync.
  - Health: `redis-cli` ping with port + password.
- Rationale:
  - Laradock parity: env password/port must apply to native Redis; users must not manually edit `redis.conf`.
- Impact:
  - `lib/services/native_redis_config.sh`, drivers, `services.sh`, docs, smoke.

## 2026-08-05 - D-121 - Stack Service Env Defaults (Laradock Parity)

- Status: accepted
- Decision:
  - Laradock-aligned `PLUME_*` defaults for Redis, MongoDB, RabbitMQ, mongo_webui, redis_webui (`defaults.sh`, `.env.example`): port, user, password, management port, web UI auth.
  - Apply at runtime after `.env` change: `services restart <svc> --mode=native`; npm web UI services read env at start.
  - CLI: `env set PLUME_*=...`, `services env show|set <svc> <short=val>` (`password=`, `port=`, …); apply immediately with `--restart`.
  - Laradock mapping table: `docs/operations/env-contract.md`.
- Rationale:
  - Native stack operations should feel close to Laradock `.env` habits; password/port changes need a documented restart path.
- Impact:
  - `lib/common/stack_service_env.sh`, `lib/config/defaults.sh`, `native_host_service_drivers.sh`, `envcmd.sh`, `services.sh`, tests, docs.

## 2026-08-04 - D-120 - Phase 17 Gate Closure (Native Stack Host Parity)

- Status: accepted
- Decision:
  - Phase 17 official closure: tracker `done`, completed 2026-08-04.
  - Gate: native drivers + `services url|credentials` + `@cache` + auto-provision D-119, phase17 smoke in release chain, `./tests/run_smoke_suite.sh --release` green.
- Rationale:
  - AGENTS.md phase-gate.
- Impact:
  - `implementation/phases/phase-17.md`, `implementation/11-status-2026-08-04.md`, release runner, CI workflow.

## 2026-08-04 - D-119 - Phase 17 Native Stack Host Parity (Scope)

- Status: accepted
- Decision:
  - Phase 17 services in native mode: mariadb, mysql, postgres, phpmyadmin, redis, mongodb, rabbitmq, mongo_webui, **redis_webui** (new registry; Laradock `redis-webui` alias).
  - OS matrix: macOS brew + Linux apt/dnf; docs [native-stack-os-matrix.md](../docs/operations/native-stack-os-matrix.md); AGENTS.md §9.
  - **redis_webui** product: **redis-commander** (npm global); RedisInsight documented as alternative.
  - Auto-provision: `PLUME_NATIVE_SERVICE_AUTO_PROVISION=true` default — native `services up` install+start on enabled services (Mailpit model extended); `--no-provision` escape.
  - CLI: `services url`, `services credentials`; `@cache` group; `@db` safe-order (DB engine → phpmyadmin).
- Rationale:
  - Laradock-parity native experience; operational command surface beyond YAML/env.
- Impact:
  - `lib/services/native_host_service_drivers.sh`, `native_host_provision.sh`, `registry.sh`, `services.sh`, tests, docs.

## 2026-07-29 - D-118 - Phase 16 Gate Closure (plume.yml v2 MVP)

- Status: accepted
- Decision:
  - Phase 16 official closure: tracker `done`, completed 2026-07-29.
  - Gate: MVP loader + `project config show` + `site add` php/mode hint, D-117, `tests/phase16_plume_yml_v2_smoke.sh` in release chain, `./tests/run_smoke_suite.sh --release` green.
  - Stretch (manifest sync, `services.enabled[]`) remains in Phase 16b or later-phase backlog.
- Rationale:
  - AGENTS.md phase-gate: test + documentation + decision record.
- Impact:
  - `implementation/phases/phase-16.md`, `implementation/phase-tracker.md`, `implementation/10-herd-parity-and-beyond.md`, `implementation/11-status-2026-07-29.md`, `implementation/future-roadmap.md`.

## 2026-07-28 - D-117 - Phase 16 plume.yml v2 MVP (Schema, Loader, Merge)

- Status: accepted
- Decision:
  - MVP fields for project-root `plume.yml`: `project.mode`, `project.php_version`, `project.type` (optional); optional root `version` and phase-4 backward-compatible root `mode`.
  - Mode resolution precedence (manifest side): CLI `--mode` > `project.mode` > root `mode` > `PLUME_MODE` / hint > `mode current`.
  - PHP version: if `--php` / `--php-version` is not given in `site add`, `project.php_version` is used as a hint; installed version list (`PLUME_PHP_INSTALLED_VERSIONS` / env) has the final say in validation.
  - Stack enable / service profile: user `~/.config/plume/services.yml` + `.env` (D-103/D-104); project manifest service toggles are Phase 16 stretch — not loaded in this phase.
  - Site registry (`~/.config/plume/sites` or `PLUME_SITE_REGISTRY_DIR`): when record fields (domain, path, mode, php_version) conflict with the manifest, CLI and registry record are authoritative for site operations; manifest is only an onboarding hint/resolution layer (no automatic registry sync).
  - Loader: `lib/common/plume_yml.sh`; visibility: `plumectl project config show --path=...`.
- Rationale:
  - Deliver the narrow MVP slice of the D-089 backlog with code + hermetic smoke; clarify `project.*` fields without breaking phase-4 mode behavior.
- Impact:
  - `lib/common/plume_yml.sh`, `lib/commands/site.sh`, `lib/commands/project.sh`, `tests/phase16_plume_yml_v2_smoke.sh`, `tests/run_smoke_suite.sh --release`, `docs/operations/project-plume-yml.md`, `docs/commands/project-config.md`.

## 2026-07-28 - D-116 - Phase 15 CI / Release Readiness Parity

- Status: accepted
- Decision:
  - The `phase15_scheduler_queue_smoke.sh` step inside `tests/run_smoke_suite.sh --release` is aligned 1:1 with `.github/workflows/smoke-tests.yml` (README `--ci` claim).
  - `docs/operations/release-readiness.md` adds the Phase 15 step to the release chain list.
  - `implementation/phases/phase-15.md` gate structure is aligned with phases 13/14; `phase-15-scheduler-queue.md` is marked as archive.
- Rationale:
  - At D-115 closure the local release runner was green but the Actions workflow was still missing; phase-gate documentation consistency.
- Impact:
  - `.github/workflows/smoke-tests.yml`, `docs/operations/release-readiness.md`, `implementation/phases/phase-15.md`, `phase-15-scheduler-queue.md`, `implementation/11-status-2026-07-27.md`, `implementation/README.md`.

## 2026-07-28 - D-115 - Phase 15 Gate Closure (Scheduler / Queue / Manifest)

- Status: accepted
- Decision:
  - Phase 15 official closure: tracker `done`, completed 2026-07-28.
  - Gate criteria: schedule/queue command set (D-111, D-112), horizon/php_worker manifest limits (D-113), `schedule cron-install` (D-114), command docs, `tests/phase15_scheduler_queue_smoke.sh` in release chain, `./tests/run_smoke_suite.sh --release` green.
  - Out of scope (Phase 15+ backlog): `plume.yml` v2 and docker-lite deepening — [phase-15-backlog-plume-yml-dockerlite.md](phases/phase-15-backlog-plume-yml-dockerlite.md).
- Rationale:
  - AGENTS.md phase-gate: test + documentation + decision record; operational scheduler/queue MVP goal met.
- Impact:
  - `implementation/phase-tracker.md`, `implementation/phases/phase-15.md`, `phase-15-scheduler-queue.md`, `implementation/11-status-2026-07-28.md`, `README.md`, `implementation/05-decision-log.md`.

## 2026-07-28 - D-114 - Phase 15 Plume-Managed Scheduler Crontab Install

- Status: accepted
- Decision:
  - Subcommand: `plume schedule cron-install` (`--path=`, `--dry-run`, `--remove`); user crontab (never root).
  - Single line: `* * * * * cd <project> && <php> artisan schedule:run >> /dev/null 2>&1 # plume-laravel-schedule-cron`; PHP resolution same as D-112 (`PLUME_PHP_BIN` / site version).
  - Install: merge with `crontab -l`; if marker exists, idempotent exit `0`; remove only lines that contain the marker.
  - Hermetic test: `PLUME_CRONTAB_FILE` temp file (real crontab untouched).
  - `schedule status` INFO: suggests `cron-install`; `CRON_HINT` stays generic `php`.
- Rationale:
  - Phase 15 third slice: Herd-like one-command minutely scheduler; safe merge instead of MVP manual copy-paste.
- Impact:
  - `lib/commands/schedule_queue.sh`, `lib/commands/help.sh`, `docs/commands/schedule.md`, `implementation/phases/phase-15.md`, `phase-15-scheduler-queue.md`, `implementation/05-decision-log.md`, `tests/phase15_scheduler_queue_smoke.sh`.

## 2026-07-28 - D-113 - Phase 15 Tracker and Horizon Manifest Limits

- Status: accepted
- Decision:
  - Phase 15 official checklist: `implementation/phases/phase-15.md`; tracker row `in-progress`.
  - For `services.yml` horizon / php_worker / supervisor: env toggle only; no native `provision --from-manifest`; docker-lite `laravel-horizon` mapping documented.
- Rationale:
  - After Phase 15 second slice, remove manifest ambiguity; clarify supervisor expectation for Horizon in native.
- Impact:
  - `docs/operations/services-manifest.md`, `implementation/phase-tracker.md`, `implementation/phases/phase-15.md`, `phase-15-scheduler-queue.md`.

## 2026-07-28 - D-112 - Phase 15 Schedule List / Run-Once / Queue Failed List

- Status: accepted
- Decision:
  - `plume schedule list` and `plume schedule run-once`: same project resolution as D-111; `php artisan schedule:list` / `schedule:run --no-interaction`; site PHP version or `PLUME_PHP_BIN`; no plume crontab install.
  - `run-once --dry-run`: only prints the planned shell line; after successful `run-once`, if crontab is `not-configured`, emit `CRON_HINT` INFO.
  - `plume queue list`: `php artisan queue:failed`; if Horizon env is on, document + INFO for `horizon:status` / `services status horizon` (no separate Artisan call).
  - Exit: plume errors `2`; Artisan failure `1` (passthrough).
  - Smoke: mock `php` + expanded `phase15_scheduler_queue_smoke.sh`.
- Rationale:
  - Phase 15 second slice: Artisan wrappers and operational test; full cron install is the next checklist item.
- Impact:
  - `lib/commands/schedule_queue.sh`, `lib/commands/help.sh`, `docs/commands/schedule.md`, `docs/commands/queue.md`, `implementation/phases/phase-15-scheduler-queue.md`, `implementation/05-decision-log.md`, `tests/phase15_scheduler_queue_smoke.sh`.

## 2026-07-27 - D-111 - Phase 15 Scheduler/Queue Status MVP

- Status: accepted
- Decision:
  - Separate top-level commands: `plume schedule status`, `plume queue status` (`lib/commands/schedule_queue.sh`); no `ops` namespace (existing `sync`/`status` router pattern).
  - Project path resolution order: `--path=` → registered site (CWD prefix) → `artisan` in CWD → active mode workspace + `artisan`.
  - Scheduler MVP: scan user crontab (`schedule:run`, optional `# plume-laravel-schedule-cron` marker); no automatic cron install; `CRON_HINT` always `* * * * * cd ... && php artisan schedule:run`.
  - Queue MVP: `.env` `QUEUE_CONNECTION`/`QUEUE_DRIVER`; `PLUME_HORIZON_ENABLED` / supervisor / php_worker env + `plume_services_display_status_line`; no full supervisor install in native — status + `./plume.sh services up horizon` hint.
  - Release smoke: `tests/phase15_scheduler_queue_smoke.sh` (`run_smoke_suite.sh --release`).
- Rationale:
  - Phase 15 first slice: operational visibility and Herd-like guidance; worker install/compose expansion in later checklist items.
- Impact:
  - `lib/bootstrap.sh`, `lib/commands/help.sh`, `docs/commands/schedule.md`, `docs/commands/queue.md`, `docs/commands/README.md`, `implementation/phases/phase-15-scheduler-queue.md`, `tests/phase15_scheduler_queue_smoke.sh`, `tests/run_smoke_suite.sh`.

## 2026-07-27 - D-110 - macOS Local Dev Ergonomics (Extension Sync + TCC Path Warnings)

- Status: accepted
- Decision:
  - Default recommendation for daily macOS development: `PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE=target` (`templates/native-local.env.example`, `.env.example` comments, `docs/operations/local-dev-macos.md`).
  - `matrix` profile remains for multi-PHP-version sync; prod preset aligned with `target`.
  - `site add` / successful `site update`: always `plume_warn` for TCC-sensitive paths + `~/Sites/<basename>` and `init permissions --interactive` hint (JSON: `warnings`).
  - `site check --json`: `data.tcc_risk` boolean; TCC text in `warnings` and in text output as `tcc_risk` / `tcc_hint`.
- Rationale:
  - Full extension matrix sync is slow/pecl-error-prone for daily `services up php`; a single target version is enough for a Herd-like flow.
  - TCC risk for sites under Desktop/Documents/Downloads (e.g. tunnelion) must not disappear from command output.
- Impact:
  - `lib/common/macos_permissions.sh`, `lib/commands/site.sh`, `docs/operations/local-dev-macos.md`, `docs/contracts/cli-output-contract.md`, `tests/phase11_native_env_presets_smoke.sh`.

## 2026-07-27 - D-109 - Native Mailpit Host Provision (Homebrew) + Doctor Port-80 UX

- Status: accepted
- Decision:
  - `mailpit` native host provision: macOS Homebrew `brew install mailpit` + `brew services start mailpit` (`plume_native_host_provision_*`).
  - `services up mailpit` / `install mailpit` run the brew path for mailpit even without global `PLUME_NATIVE_HOST_PROVISION` (`plume_native_host_provision_service_wants`).
  - Linux/apt: unsupported; `services up mailpit` and manifest provision clear WARN + exit 2; docker-lite or manual install.
  - `services provision --from-manifest`: brew install/start for `mailpit.enabled: true` (macOS).
  - `doctor web`: when Homebrew 8080 + registry port 80, `listener-80` / `sites-port80` WARN lines hint `services web sync-config --reload` + `site check`.
- Rationale:
  - Herd parity: development mail capture should open with one command on the native stack; a one-line fix path for portless URL / 8080 confusion.
- Impact:
  - `lib/services/native_host_provision.sh`, `lib/common/services_manifest.sh`, `lib/services/registry.sh`, `lib/commands/doctor.sh`, `docs/commands/services.md`, `docs/commands/services-provision.md`, `docs/operations/services-manifest.md`, `docs/commands/services-web.md`, `tests/phase12_native_host_provision_mailpit_smoke.sh`, `implementation/phases/phase-15-scheduler-queue.md` (backlog stub).

## 2026-07-27 - D-108 - Manifest `provision.on_first_run` (One-Shot Host Bootstrap)

- Status: accepted
- Decision:
  - When `services.yml` → `provision.on_first_run: true`, in native mode and without `PLUME_STATE_DIR/on_first_run_provision.done`, run `services provision --from-manifest` once.
  - Triggers: first meaningful CLI bootstrap (except `help`/`version`/`init`) or `init host` (`maybe` without `--apply`; direct provision + flag with `--apply`).
  - Flag is written when manual `services provision --from-manifest` or `--apply` succeeds (idempotent).
  - `PLUME_SKIP_ON_FIRST_RUN_PROVISION=true` smoke/test opt-out; `provision.interactive: false` → `PLUME_NONINTERACTIVE` (D-100).
- Rationale:
  - Greenfield users can skip `init host --apply`; with template `on_first_run: true`, stack setup should automate.
- Impact:
  - `lib/common/services_manifest.sh`, `lib/bootstrap.sh`, `lib/commands/init_host_onboarding.sh`, `docs/operations/services-manifest.md`, `tests/phase11_services_manifest_smoke.sh`.

## 2026-07-26 - D-107 - Homebrew FPM Pool `listen` Aligned Before `brew services start`

- Status: accepted
- Decision:
  - Native macOS `plume_native_php_start_fpm_service` (brew) runs `plume_native_php_ensure_fpm_listen` before `brew services start`:
    - If `listen` in `www.conf` (or test: `PLUME_PHP_FPM_WWW_CONF`) does not match the Plume canonical unix path, update it (`plume_sites_php_canonical_homebrew_socket`, e.g. `/opt/homebrew/var/run/php@8.2-fpm.sock`).
    - Idempotent: no-op when already correct; first change takes a `www.conf.plume-bak` backup.
  - After start, `plume_native_php_verify_fpm_after_brew_start`: verify canonical socket with `-S`; otherwise php-fpm log tail + `exit 2` (e.g. `127.0.0.1:9000` port conflict).
  - `PLUME_PHP_NATIVE_INSTALL_DRIVER=mock` skips ensure/verify (smoke compatibility); hermetic listen smoke: `PLUME_PHP_FPM_ENSURE_LISTEN_SOCKET` + `PLUME_PHP_FPM_WWW_CONF`.
- Rationale:
  - Homebrew default pool `listen = 127.0.0.1:9000`; multi-version port conflicts take FPM down while the site expects `php@8.2-fpm.sock`.
- Impact:
  - `lib/services/registry.sh`, `docs/commands/services.md`, `docs/commands/php.md`, `docs/commands/site.md`, `tests/phase11_native_php_ensure_fpm_listen_smoke.sh`.

## 2026-07-26 - D-106 - Native `services up php` Starts Versioned Homebrew FPM

- Status: accepted
- Decision:
  - On the native `plume_service_start_native` PHP path, after binary/auto-provision, start host FPM:
    - macOS brew: `brew services start php@<major.minor>` (`plume_native_php_brew_service_name`; if formula missing, same name is tried; default version + installed `php` formula uses service name `php`).
    - Linux apt: `systemctl start php<major.minor>-fpm`.
  - `services down php` / `php82` stops the target version FPM service; does not affect other versions.
  - `PLUME_PHP_NATIVE_INSTALL_DRIVER=mock` does not call real brew/systemd (smoke compatibility).
- Rationale:
  - `services up php82` only wrote state/log and did not run `brew services start php@8.2`; site nginx expected `php@8.2-fpm.sock` while FPM was down.
- Impact:
  - `lib/services/registry.sh`, `docs/commands/services.md`, `tests/phase11_services_up_php_native_brew_start_smoke.sh`.

## 2026-07-26 - D-105 - Non-Default Native PHP Upstream Must Not Alias Default TCP Pool

- Status: accepted
- Decision:
  - Native `plume_sites_php_upstream_for_version` resolver order was expanded:
    1. env override (`PLUME_NATIVE_PHP_FPM_UPSTREAM`, `..._<major><minor>`)
    2. existing unix socket (via `-S`)
    3. installed pool config `listen` (outside default version or shared `127.0.0.1:9000`)
    4. non-default version + Homebrew `php@X.Y` installed → canonical `unix:.../php@X.Y-fpm.sock` (do not fall to shared TCP pool)
    5. default version → `127.0.0.1:9000` fallback
  - Most Homebrew `php-fpm` pools use `listen = 127.0.0.1:9000`; that upstream is accepted only for default PHP.
- Rationale:
  - With site record `php_version: 8.2`, even if the snippet header is correct, `fastcgi_pass 127.0.0.1:9000` goes to the running default pool (e.g. php@8.3); silent wrong runtime.
- Impact:
  - Per-version native routing is safer; for php@8.2, `services up php82` + pool listening on unix socket (or `--php-upstream`) is expected.
  - Smoke: `tests/phase11_site_php_upstream_resolver_smoke.sh`

## 2026-07-26 - D-104 - Full Registry `services.yml` Mapping (Schema v1 Extension)

- Status: accepted
- Decision:
  - `templates/services.yml.example` covers all `plume_service_names` registry services (web/php/database special blocks + registry toggle/version).
  - Single env mapping table: `plume_services_manifest_env_mapping_rows` (`lib/common/services_manifest.sh`); aligned with `plume_service_env_key` / `plume_service_version_env_key`.
  - YAML reading: block scalar + inline `{ enabled: true, version: "16" }`; missing key = defaults (backward compatible).
  - `services manifest show`: `effective_<service>_enabled` and (when present) `effective_<service>_version` lines for every registry service.
  - `services provision --from-manifest`: best-effort host PHP install for natively supported packages (web, mariadb, mysql, redis) + manifest `php.versions`; warning for other enabled services (docker/manual).
  - Laradock-only `workspace` / `php-fpm`: example YAML comments; native loader no-op.
- Rationale:
  - D-103 MVP was only web/php/database/redis; managing all PLUME_*_ENABLED via one YAML is needed for adapter and greenfield setup.
- Impact:
  - `lib/common/services_manifest.sh`, `templates/services.yml.example`, `docs/operations/services-manifest.md`, `docs/commands/services-provision.md`, `docs/operations/ai-assisted-development.md`, `tests/phase11_services_manifest_full_smoke.sh`, `implementation/05-decision-log.md`.

## 2026-07-26 - D-103 - Native `services.yml` Stack Manifest (MVP)

- Status: accepted
- Decision:
  - Central native stack manifest: `~/.config/plume/services.yml` (override: `PLUME_SERVICES_MANIFEST_FILE`); repo template `templates/services.yml.example`.
  - Merge: `plume_load_defaults` → `plume_services_manifest_apply` → `plume_load_env` → `plume_load_defaults` (php.env); `.env` overwrites YAML on the same keys.
  - Loader: `lib/common/services_manifest.sh`; bootstrap order updated in `lib/bootstrap.sh`.
  - Commands: `init host` manifest bootstrap + `--apply`; `services manifest show`; `services provision --from-manifest [--dry-run]`.
  - `host.env` remains for machine identity; service toggles live in the manifest + env layer.
- Rationale:
  - Laradock-like greenfield native setup via one YAML; existing `.env`-only users are unaffected (no manifest = no-op).
- Impact:
  - `lib/common/services_manifest.sh`, `lib/bootstrap.sh`, `lib/config/defaults.sh`, `lib/commands/init_host_onboarding.sh`, `lib/commands/services.sh`, `templates/services.yml.example`, `docs/operations/services-manifest.md`, `docs/commands/services-provision.md`, `docs/operations/first-run-onboarding.md`, `docs/operations/env-contract.md`, `tests/phase11_services_manifest_smoke.sh`.

## 2026-07-26 - D-102 - AI Development Prompt Record

- Status: accepted
- Decision:
  - Durable AI/human pair-programming context: `docs/operations/ai-assisted-development.md` (session bootstrap, smoke strategy, pre-PR checklist).
  - Cursor always-on rule: `.cursor/rules/plume-smoke-and-agents.mdc`.
  - `AGENTS.md` §5 and the README Test section link to this guide.
- Rationale:
  - Smoke suite and hermetic test fixes (PATH, pipefail, nginx strict, macOS TCC) were being forgotten across sessions.
- Impact:
  - Copy-paste bootstrap in new chats; agent rules remind smoke/doc obligations.

## 2026-07-26 - D-101 - Unified Smoke Suite Entrypoint

- Status: accepted
- Decision:
  - Single local/CI alignment script: `tests/run_smoke_suite.sh` (`--release` default, `--ci`, `--phase11-full`, `--all`; `--linux` / `PLUME_RUN_LINUX_TESTS=1` for the phase3 Linux matrix).
  - `--release` and `--ci` run the same step list (`.github/workflows/smoke-tests.yml`); `*e2e_matrix*` aggregators are excluded from `--all` (prevent double runs).
- Rationale:
  - README, runbook, and Actions presented different command lists; a single fail-fast chain was needed before release.
- Impact:
  - Release readiness and README point to this script; existing individual smoke scripts stay unchanged.

## 2026-07-26 - D-100 - Interactive macOS Permission and Host Install Prompts

- Status: accepted
- Decision:
  - New module: `lib/common/macos_permissions.sh` — TTY/`PLUME_INTERACTIVE` detection, TCC menu (open FDA, suggest ~/Sites, continue/cancel), brew install confirm (`PLUME_NATIVE_HOST_PROVISION`), optional sudo nginx port 80 confirm.
  - TCC path scope: Desktop, Documents, **Downloads** (`plume_sites_path_is_macos_tcc_sensitive`).
  - Hook: `site add`, `site update --path`, `init host`, `init onboarding`, `init permissions --interactive`, site auto-provision web, `doctor web`/`doctor php` WARN line hints `init permissions --interactive`.
  - CI: `PLUME_NONINTERACTIVE=1` and global `--yes` (`PLUME_ASSUME_YES`) skip prompts; without TTY, install continues without confirm (existing smoke compatibility).
  - No automatic FDA grant — only explanation, open System Settings, Finder reveal.
- Rationale:
  - Projects under Desktop (e.g. tunnelion) need manual macOS steps due to TCC; Plume should guide and document the honest TCC boundary.
- Impact:
  - `lib/common/macos_permissions.sh`, `lib/bootstrap.sh`, `lib/common/sites.sh`, `lib/commands/site.sh`, `lib/commands/init_host_onboarding.sh`, `lib/services/native_host_provision.sh`, `lib/services/native_web_nginx_config.sh`, `lib/commands/doctor.sh`, `docs/operations/macos-permissions.md`, `docs/commands/init-permissions.md`, `docs/commands/site.md`, `docs/operations/first-run-onboarding.md`, `tests/phase11_macos_permissions_smoke.sh`.

## 2026-07-26 - D-099 - macOS Full Disk Access Onboarding UX (CLI, Not an App)

- Status: accepted
- Decision:
  - Plume `./plume.sh` / `plumectl` is not a GUI app; FDA docs do **not** add a Plume app or plume.sh.
  - `init onboarding` / `doctor onboarding`: default output resolves nginx and php-fpm binary paths (`command -v`, `brew --prefix`, `plume_php_find_fpm_bin`); optional Terminal/iTerm path.
  - `--fix`: only safe host fixes (Homebrew `brew services start nginx` + installed PHP formula); **System Settings is not opened automatically**.
  - `--open-settings`: explicitly open the FDA pane (previous `--fix` behavior removed).
  - `init permissions --open`: binary list + warning before opening; `--reveal` shows nginx bin directory in Finder.
  - Dev/repo detection (`PLUME_REPO_ROOT` or `ROOT_DIR` + `.git` + `plume.sh`): suggest a non-Desktop path, optional FDA emphasis.
- Rationale:
  - Users opening FDA via `init onboarding --fix` do not see a "Plume" entry to add; TCC mainly affects nginx/php-fpm daemon binaries.
- Impact:
  - `lib/commands/init_host_onboarding.sh`, `lib/commands/help.sh`, `docs/commands/init-onboarding.md`, `docs/commands/init-permissions.md`, `docs/operations/first-run-onboarding.md`, `tests/phase11_host_onboarding_smoke.sh`.

## 2026-07-26 - D-098 - Host Profile Persistence and First-Run Onboarding

- Status: accepted
- Decision:
  - Machine identity is persisted as `~/.config/plume/host.env` (`key=value`); fields: `os`, `os_version`, `arch`, `package_manager`, `web_driver_hint`, `nginx_http_port_detected`, `homebrew_nginx`, `state_dir`, `detected_at`; for Windows `native_support_note`.
  - Commands: `init host`, `init onboarding [--fix] [--open-settings]`, `init permissions [--open] [--reveal]`; doctor aliases: `doctor host`, `doctor onboarding [--fix] [--open-settings]`.
  - `PLUME_AUTO_HOST_BOOTSTRAP=true` (default): if no profile, idempotent detect on first CLI entry (no-op if file exists).
  - Windows: profile only; full native nginx/site publish is out of scope for this decision.
- Rationale:
  - Users should not learn TCC, Homebrew 8080, and config paths piece by piece; one onboarding path aligned with existing `plume_detect_os`, `doctor web` (`macos-site-tcc`), `services web sync-config`.
- Impact:
  - `lib/common/host_profile.sh`, `lib/common/os.sh`, `lib/commands/init_host_onboarding.sh`, `lib/bootstrap.sh`, `docs/operations/first-run-onboarding.md`, `docs/commands/init-*.md`, test smoke.

## 2026-07-26 - D-097 - Nginx Laravel PHP Location (Front Controller + macOS TCC)

- Status: accepted
- Decision:
  - PHP location in the native nginx site snippet aligned to Laravel standard: `try_files $uri =404`, `fastcgi_split_path_info`, `include fastcgi_params` then `SCRIPT_FILENAME` (`$realpath_root$fastcgi_script_name`).
  - macOS TCC: WARN in `doctor web` (`macos-site-tcc`) and `doctor php` (`MACOS_TCC`) for site paths under Desktop/Documents; `site.md` troubleshooting section.
- Rationale:
  - After front-controller internal redirect, some installs get empty/wrong SCRIPT_FILENAME; also distinguish php-fpm "No input file specified" / Operation not permitted on Desktop paths.
- Impact:
  - `lib/common/sites.sh`, `lib/commands/doctor.sh`, `lib/commands/site.sh`, `docs/commands/site.md`, `docs/commands/status-health-logs.md`, `tests/phase11_site_nginx_php_front_controller_smoke.sh`.

## 2026-07-26 - D-096 - Per-Site TLS Disable via `site update --clear-cert`

- Status: accepted
- Decision:
  - Added `site update <id> --clear-cert` to disable per-site HTTPS (`--tls=false` alias).
  - Removes `cert_id` and `https_port` fields from the record; publish render produces an HTTP-only snippet with `tls_enabled=false` (no nginx/apache2 redirect block).
  - Certificate artifacts remain under `$(plume_state_dir)/certs/<id>/`; can be rebound with `--cert-id`.
  - `--clear-cert` is rejected on `site add`; `--clear-cert` cannot be combined with a non-empty `--cert-id`.
- Rationale:
  - In local development, TLS must be disableable without deleting the site record when HTTP→HTTPS redirect is unwanted.
  - Prefer an explicit CLI flag matching existing site command patterns over a separate `tls_enabled` yaml field.
- Impact:
  - `lib/commands/site.sh`, `docs/commands/site.md`, `docs/commands/security.md`, `tests/phase11_site_clear_cert_smoke.sh`.

## 2026-07-26 - D-095 - sync-config --reload: plume_sites_reload_native wiring

- Status: accepted
- Decision:
  - `plume_native_nginx_reload_for_http_port` directly calls `plume_sites_reload_native nginx` (`sites.sh`, loaded during bootstrap).
  - Wrong/missing helper name (`plume_sites_reload_native_server`) removed; after failed reload, `brew services restart nginx` fallback and a clear error message.
- Rationale:
  - `services web sync-config --reload` left nginx unreloaded after main config patch (`nginx reload helper unavailable`).
- Impact:
  - `lib/services/native_web_nginx_config.sh`, `docs/commands/services-web.md`, smoke: `tests/phase11_services_web_sync_config_reload_smoke.sh`.

## 2026-07-26 - D-094 - Native Nginx Main Config Port Management (Homebrew 8080 → 80)

- Status: accepted
- Decision:
  - Homebrew nginx formula rewrites `listen 80` → `8080` at build time (to avoid needing root; source: `homebrew-core` `Formula/n/nginx.rb`).
  - Opt-in env: `PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG`, `PLUME_NATIVE_NGINX_HTTP_PORT` (default `80`), optional `PLUME_NATIVE_NGINX_MAIN_CONF`.
  - New commands: `services web sync-config`, `services web port <n>`, `doctor web fix-ports` (same sync helper).
  - Sync: backup + main `nginx.conf` listen patch + `nginx -t` + optional reload; sudo brew services message for macOS port 80.
  - `plume_sites_effective_http_port`: reads main config listen; if 80, site render is not forced to 8080 (`PLUME_NATIVE_HOMEBREW_HTTP_PORT` explicit override preserved).
- Rationale:
  - Mismatch between portless `http://myapp.test` and Homebrew default 8080; Plume must manage main nginx access beyond snippets.
- Impact:
  - `docs/commands/services-web.md`, env-contract, site.md, status-health-logs; smoke: `tests/phase11_services_web_sync_config_smoke.sh`.

## 2026-07-26 - D-093 - Doctor Web: Native Webserver and Port Diagnostics

- Status: accepted
- Decision:
  - New subcommand: `doctor web [--mode=...] [--strict]`.
  - In native mode: `PLUME_WEB_SERVER_DRIVER`, binary path, brew/systemd service status, `listener-effective` (registry + `plume_sites_effective_http_port`), port 80/443 listeners, nginx strict include target vs plume cache comparison, and registry `port: 80` site warning.
  - Critical FAIL + `--strict` → exit code `2` (same discipline as `doctor php`).
- Rationale:
  - For `myapp.test` / ERR_CONNECTION_REFUSED cases, clarify whether the web service is running and whether the port is 80 or 8080; `site check` alone is not enough.
- Impact:
  - `docs/commands/status-health-logs.md` updated; smoke: `tests/phase11_doctor_web_smoke.sh`.

## 2026-07-25 - D-092 - Site Check: Effective Port and Open URLs

- Status: accepted
- Decision:
  - Added `effective_http_port`, `url_http`, `url_https` (if cert present), `access_hint` to `site check` output.
  - When registry `port: 80` + Homebrew nginx `8080`, show the user a clear URL; portless `http://domain` fails because port 80 is not listening.
- Rationale:
  - ERR_CONNECTION_REFUSED diagnosis came from confusing registry port with the real listen port.
- Impact:
  - Adapter `--json` `site check` schema expanded (non-breaking additive fields + optional warnings).

## 2026-07-25 - D-091 - Native Site Publish: Strict on Reload, Homebrew Port, PHP Upstream

- Status: accepted
- Decision:
  - `PLUME_SITE_NGINX_STRICT_ON_RELOAD=true` (default): `site publish --reload` writes the snippet under Homebrew `nginx/servers/`.
  - Create the Homebrew `servers/` directory if missing.
  - If site `port: 80` + macOS Homebrew nginx `listen 8080`, render port automatically becomes 8080 (`plume_sites_effective_http_port`).
  - Native PHP upstream fallback: `127.0.0.1:9000` (instead of docker `php-fpm:9000`).
  - Nginx PHP location: `$realpath_root` (Laravel compatibility).
- Rationale:
  - Domains were unreachable because publish cache and running nginx diverged.
- Impact:
  - With `--reload`, the vhost binds to real nginx; HTTPS cert sites use `:4443`.

## 2026-07-25 - D-090 - Site Publish Auto-Provision Web Runtime on Reload

- Status: accepted
- Decision:
  - New env: `PLUME_SITE_AUTO_PROVISION_WEB=true` (default).
  - Before native `site publish --reload`, run `plume_sites_native_ensure_web_runtime`:
    - if nginx binary is missing, host-provision `web` install + start (brew/apt).
    - if binary exists but brew service is stopped, `brew services start nginx`.
  - With `PLUME_SITE_AUTO_PROVISION_WEB=false`, previous behavior (warn only, do not install).
- Rationale:
  - User expectation: Plume should manage the web server with site publish; a reload warning when nginx is missing is not enough.
- Impact:
  - First `--reload` on macOS may install nginx via Homebrew (needs network access).

## 2026-07-25 - D-089 - Backlog: plume.yml v2 and Docker-Lite Unfreeze (Deferred)

- Status: accepted
- Decision:
  - Broader `plume.yml` manifest (site + enabled services + php version) stays Phase 15+ backlog; phase-4 baseline (`mode` resolution) is preserved.
  - Docker-lite `beta-frozen` status is preserved; unfreeze is planned as a separate phase (compose requirements, image slimming).
- Rationale:
  - Phase 12-14 focus is native host provisioning, deploy apply, and release/CI stabilization.
- Impact:
  - Clear decision record for manifest and docker-lite deepening; prevents scope creep.

## 2026-07-25 - D-088 - Phase 14: CI Smoke Matrix + Golden JSON Baseline

- Status: accepted
- Decision:
  - PR workflow: `phase10_e2e_matrix_smoke.sh` (includes phase 11 runner) + `phase14_golden_json_smoke.sh`.
  - Manual release workflow runs the same smoke chain before the release job.
  - Golden snapshot tests initial scope: `prereq check --json`, `services supported --json`, `mode current --json`.
- Rationale:
  - Adapter-readiness and release no-go rules must be wired into automation.
- Impact:
  - Regressions are caught at PR level; CLI contract breaks are seen early.

## 2026-07-25 - D-087 - Phase 13: Deploy Apply Baseline (Reconcile + Health Gate)

- Status: accepted
- Decision:
  - Implemented `deploy apply`: optional pre-deploy backup, `doctor check --deep`, `services update`, `monitor summary --strict`.
  - Added `--dry-run`, `--skip-backup`, `--skip-health` flags.
  - Critical action is confirmed with `--yes deploy apply`.
- Rationale:
  - Close the missing link in the `deploy plan` chain; provide an operate journey compatible with rollback/failback.
- Impact:
  - Production ops docs and smoke tests are updated.

## 2026-07-25 - D-086 - Phase 12: Native Host Provisioning Opt-In (`PLUME_NATIVE_HOST_PROVISION`)

- Status: accepted
- Decision:
  - Default behavior preserved: state/port orchestration (simulate).
  - When `PLUME_NATIVE_HOST_PROVISION=true`, real host install/start/stop for `@core/@web/@db` services:
    - `nginx`, `apache2`, `mariadb`, `mysql`, `redis` (brew/apt; dnf best-effort).
  - PHP install continues via the existing native PHP driver (no separate env required).
- Rationale:
  - Real host provisioning can be enabled without breaking existing smoke tests.
- Impact:
  - Herd-like one-command experience via opt-in; phase 12 smoke runs in state mode.

## 2026-07-25 - D-085 - Phase 11 Closure: Native Adapter Contract Parity Completed

- Status: accepted
- Decision:
  - Phase 11 gate items completed; phase closed as `done`.
  - Added `tests/phase11_e2e_matrix_smoke.sh` to the release matrix; README and parity checklist synced.
  - Open risks handed to Phase 12+ (launchd/systemd edge-cases, adapter JSON differences).
- Rationale:
  - Phase-gate discipline (test + docs + decision record) must be completed.
- Impact:
  - Tracker and docs reflect the real maturity level.

## 2026-07-25 - D-084 - Native Nginx Reload Detection Includes Homebrew Prefix

- Status: accepted
- Decision:
  - Native reload/validate flow, if `nginx` binary is not on PATH, tries Homebrew-prefix `bin/nginx` or `sbin/nginx` paths.
- Rationale:
  - On macOS, even with Homebrew installed, `nginx` is not always on the shell PATH.
  - The reload detector should be more resilient without depending on PATH.
- Impact:
  - `site publish --reload` produces fewer false-negatives on Homebrew nginx installs in native mode.

## 2026-07-25 - D-083 - Site Modes Registry View and Mode Drift Cleanup

- Status: accepted
- Decision:
  - Added `plumectl site modes` command.
  - This command gives a mode-grouped bulk view of site records.
  - After `site update <id> --mode=<mode>`, cache/snippet artefacts from the old mode are cleaned automatically.
- Rationale:
  - Leftover registry/config traces after mode switches caused confusion.
  - An adapter-ready system needs a fast bulk view of current mode state.
- Impact:
  - `site modes` becomes the standard view for drift checks.
  - Old snippet files do not accumulate outside mode switches.

## 2026-07-25 - D-082 - Site Update Mode Override Contract

- Status: accepted
- Decision:
  - `site update <id> --mode=<mode>` can override the site record mode field.
  - Later `site publish` and `site remove` work according to this new mode.
- Rationale:
  - Users must be able to move a site among native, docker-lite, and laradock-bridge.
  - Mode change must not require a separate re-register flow.
- Impact:
  - A registered site can move into the native reload pipeline with `site update --mode=native`.
  - Publish dispatch mode is now determined from the current record mode.

## 2026-07-25 - D-081 - Site List Table Layout Stabilization

- Status: accepted
- Decision:
  - `site list` text output layout was fixed.
  - Column order standardized as `ID, SERVER, PHP, PORT, HTTPS, CERT, STATUS, DOMAINS, PATH`.
  - `PATH` column stays last.
  - Header and rows are formatted through the same width renderer.
- Rationale:
  - Long path values were shifting the table.
  - For adapter-ready text output, column alignment and order must stay parseable.
- Impact:
  - `site list` preview regressions will be caught earlier.
  - Docs and smoke tests will use this layout as reference.

## 2026-03-06 - D-001 - Unified 3-Mode Architecture

- Status: accepted
- Decision:
  - Plume will be a single utility offering 3 runtime modes:
    - native
    - docker-lite
    - laradock-bridge
- Rationale:
  - Gather different team and infrastructure maturity levels into one tool
  - Make Laradock dependency optional
- Impact:
  - Engine abstraction is mandatory
  - Test matrix grows 3x

## 2026-03-06 - D-002 - Config as Code (YAML)

- Status: accepted
- Decision:
  - Local + production scenarios will be defined through a YAML contract
- Rationale:
  - Repeatable setup from a single source
  - Keep context clear for AI and human contributors
- Impact:
  - A schema validation layer is required
  - Backward compatibility must be planned

## 2026-03-06 - D-003 - Modular Shell and Import Standard

- Status: accepted
- Decision:
  - Plume will use a `source`-based modular shell architecture instead of one long `sh` file
  - There will be a thin entrypoint + command/engine/service modules under `lib/`
- Rationale:
  - Increase maintenance and development speed
  - Clarify phase-based separation at the code level
  - Make change impact traceable for AI/human contributors
- Impact:
  - Naming convention and import discipline are mandatory
  - Shellcheck and basic script tests should be added to the release gate

## 2026-03-06 - D-004 - OS-Aware Core Prereq Fail-Fast Policy

- Status: accepted
- Decision:
  - Plume will auto-detect the macOS/Linux split
  - Before a command runs, it will check core dependencies by profile
  - If a required package is missing, the command will stop and provide install guidance
- Rationale:
  - Reduce half-installs and ambiguous errors
  - Make infrastructure deterministic before service install
- Impact:
  - `prereq` command family and profile logic are mandatory
  - OS/distro detection tests should be added to the release gate

## 2026-03-06 - D-005 - Central Site Registry and Interactive Onboarding

- Status: accepted
- Decision:
  - Project/site add will be prompt-based via `plumectl site add`
  - Registry will be kept in a central location independent of the working directory
  - Records will always contain absolute paths
  - Nginx/Apache2/Caddy adapters will use the same registry model
- Rationale:
  - End confusion between project paths and where commands are run
  - Reduce new-project add to a single fast flow
- Impact:
  - `site` command family becomes a core piece
  - Domain/path uniqueness and drift control mechanisms are required

## 2026-03-06 - D-006 - Documentation-First Development Rule

- Status: accepted
- Decision:
  - In every development, related command docs and contract files will be updated at the same time
  - A feature without docs will not be considered complete
- Rationale:
  - Need clear behavior for API-like CLI use on the server side
  - Fast adaptation for the future `plume-adapter` project
- Impact:
  - `docs/commands` and `docs/contracts` are part of the release gate

## 2026-03-06 - D-007 - 10-Phase Gate-Driven Delivery

- Status: accepted
- Decision:
  - The roadmap will be split into 10 phases and no phase will close without test + documentation + decision record
- Rationale:
  - Shrink phase scopes and reduce risk
  - Guarantee quality before moving to the next phase
- Impact:
  - Official checklist is mandatory at phase transitions

## 2026-03-06 - D-008 - Mode-Based Service Support Visibility

- Status: accepted
- Decision:
  - The native and docker-lite supported service list will be shown both in the main docs and via a CLI command
  - Standard command: `plumectl services supported [--mode=...]`
- Rationale:
  - Instantly answer "what is supported in this mode" during operations
  - Clarify capability discovery while building the adapter
- Impact:
  - As services are added, the matrix and command output contract must be updated together

## 2026-03-06 - D-009 - Ops Constraints from Product Answers

- Status: accepted
- Decision:
  - Privilege split: install/update root, runtime commands prefer non-root
  - TLS/certificate support mandatory (docker-lite helper optional)
  - DNS management out of scope for now; later-phase backlog
  - Secret management and rollback mandatory
  - Firewall/OS security preflight mandatory
  - Docker-lite targets high parity with native
  - Pinned version + optional auto-update supported
  - JSON output guaranteed only for critical commands
  - Full E2E mandatory at phase closure
- Rationale:
  - Operational clarity and production reliability
- Impact:
  - Extra test and docs requirements arise in phases 3/6/7/9/10

## 2026-03-06 - D-010 - Supervisor Requirement for Horizon

- Status: accepted
- Decision:
  - If Laravel Horizon will run, the supervisor dependency is treated as mandatory
  - In native mode, horizon operations are managed through supervisor
- Rationale:
  - Horizon needs process management and automatic restart
- Impact:
  - Dependency rule is mandatory in `services` and `prereq` docs
  - Horizon E2E tests must include supervisor present/absent scenarios

## 2026-03-06 - D-011 - Service Custom Versions + PHP Alias Management

- Status: accepted
- Decision:
  - Custom version selection will be supported for services including Mariadb/Redis/PHP
  - Multi-version management and default `php` alias switching will be supported for PHP
  - Versioned aliases (`php81`, `php82`, `php83`) will be manageable
- Rationale:
  - Ease project-based runtime compatibility and migration processes
- Impact:
  - Version fields are added to the config contract
  - Version/alias operations become mandatory in the `services` and `php` command families

## 2026-03-06 - D-012 - Plume Naming & CLI Collision Policy

- Status: accepted
- Decision:
  - Product name is set to `Plume`
  - Official CLI binary is `plumectl`
  - `plume` is used only as an optional alias
  - Repository name is standardized as `laravel-plume`
- Rationale:
  - Reduce possible `plume` command collisions on Linux
  - Keep CLI ergonomics safe while preserving the brand name
- Impact:
  - Docs and command examples primarily use `plumectl`
  - Package/formula names are chosen to match the naming policy

## 2026-03-06 - D-013 - Herd Parity + Beyond and Laravel Lifecycle Completeness

- Status: accepted
- Decision:
  - Plume is designed so the Laravel Herd parity goal covers local + production
  - In addition, deploy orchestration, rollback, secrets, security preflight, and advanced observability are included
  - The Laravel project lifecycle is planned end-to-end as bootstrap -> runtime -> deploy -> operate -> recovery
- Rationale:
  - Complete the "easiest way to add a Laravel project to the system" goal under real operational conditions
- Impact:
  - Phase gate checklist requires lifecycle and parity checklist validation
  - Runbook and capability checklist docs are included in release criteria

## 2026-03-06 - D-014 - Laravel Ecosystem Optional Service Scope

- Status: accepted
- Decision:
  - Laravel ecosystem services such as Mailpit, Meilisearch, and MinIO are kept optional but in official scope
  - The service support matrix and config contract specify these services by mode
- Rationale:
  - Real-world Laravel projects often need mail/search/object storage
- Impact:
  - E2E scenarios should test at least one ecosystem service combination

## 2026-03-06 - D-015 - Minimal Default Services + Toggle-Aware Reconcile

- Status: accepted
- Decision:
  - In default install, only the required set (`php`, `composer`, `mariadb`, `nginx`) is active
  - Other services are default `false`
  - `services update` detects services that flip `false -> true` in config, installs and starts them automatically
- Rationale:
  - Lightness and speed on first install
  - Controlled expansion later by need
- Impact:
  - Profile/toggle/reconcile fields become mandatory in the config contract
  - E2E test scenarios are required for reconcile behavior

## 2026-03-06 - D-016 - Unified .env Contract (Shared + Mode-Specific)

- Status: accepted
- Decision:
  - All service and config variables will be overridable via `.env`
  - Root `.env.example` will include shared variables and mode-specific variable blocks
  - Prefix standard: `PLUME_*`, mode-specific: `PLUME_NATIVE_*`, `PLUME_DOCKER_LITE_*`, `PLUME_LARADOCK_*`
- Rationale:
  - Provide a single configuration flow across local/prod and mode switches
  - Keep variable names deterministic for adapter and operations sides
- Impact:
  - Config loader layer runs by env precedence rules
  - Docs and example files are included in release criteria

## 2026-03-06 - D-017 - Phase 1 Closure Baseline

- Status: accepted
- Decision:
  - Phase 1 is kept limited to the foundation goal; production-level orchestration is not forced in this phase.
  - `services install/up/down` commands are intentionally left as hook/stub behavior in Phase 1.
  - Real service orchestration, versioning, and process management are completed in Phase 6.
- Rationale:
  - Prevent scope drift between phases
  - Make CLI ergonomics testable early while carrying technical debt in a controlled way
- Impact:
  - Users can validate the command flow in Phase 1, but real service install expectations move to Phase 6
  - Docs clearly mark commands with a "phase1 stub" note

## 2026-03-06 - D-018 - Phase 2 Global Flag and Router Baseline

- Status: accepted
- Decision:
  - CLI router families (`mode/services/prereq/site/project/deploy/backup/status`) were gathered into a single dispatch table.
  - Global flag parser added: `--help`, `--version`, `--json`, `--yes`, `--quiet`, `--env-file`.
  - JSON output was enabled in Phase 2 for a critical command subset (`services supported`, `services status`, `prereq check`).
- Rationale:
  - Make commands deterministically parseable for the adapter-readiness goal
  - Reuse the same flag and output contract in later phases (prereq/site/orchestration)
- Impact:
  - Router stays stable with command-family placeholders while phase-based implementation progresses independently
  - `--env-file` makes it easy to try different test/prod config files

## 2026-03-06 - D-019 - Phase 3 OS-Aware Prereq Guard + Linux Matrix

- Status: accepted
- Decision:
  - `prereq check` moved to a profile-based fail-fast model.
  - OS/package manager detection standard clarified: macOS=`brew`, Linux=`apt|dnf`.
  - Root boundary became mandatory for install/update actions.
  - Linux verification for macOS development environments was standardized via Docker matrix (Ubuntu + Fedora).
- Rationale:
  - Catch ambiguous errors from host differences early
  - Validate Linux behavior while developing on macOS
- Impact:
  - Cross-OS smoke chain formed with `tests/phase3_prereq_smoke.sh` and `tests/linux_prereq_matrix.sh`
  - Phase 4+ commands will reuse prereq profiles in a command-level context

## 2026-03-06 - D-020 - Phase 4 Site Command Baseline

- Status: accepted
- Decision:
  - `site add/list/check/remove` commands were activated and wired to work with the `~/.config/plume/sites` registry model.
  - In non-interactive conditions, the command fails fast when `--path`/`--domain` inputs are missing.
  - Domain/path conflicts are blocked except with `force`; if publish fails, the record is removed via rollback.
- Rationale:
  - Establish the onboarding axiom that can add a Laravel project to the system in the fewest steps.
- Impact:
  - The `site` command family is accepted as the Phase 4 functional deliverable.
  - Documentation, phase plan, and parity notes are updated in lockstep.

## 2026-03-07 - D-021 - Postponed `plume.yml` Requirement

- Status: accepted
- Decision:
  - `plume.yml`-based site configuration will not be a mandatory part of the testing phase.
  - Tests and the current phase-4 onboarding flow will stay focused on the central registry.
  - Applying `plume.yml` and project-local Nginx behavior is planned after phase-4.
- Rationale:
  - Keep scope under control in test-focused phases.
- Impact:
  - Plan notes updated in `implementation/phases/phase-04.md` and `implementation/10-herd-parity-and-beyond.md`.
  - Migration path and manifest lifecycle design in later phases will follow this decision.

## 2026-03-07 - D-022 - Phase 5B Strict Mode + Dry-Run/Rollback Contract

- Status: accepted
- Decision:
  - `--dry-run` will be added to the `site` command family (`add/update/publish/remove`).
  - On `site update --publish`, if publish fails, record rollback will be applied.
  - For `laradock-bridge`, `PLUME_LARADOCK_STRICT=true` fail-fast preflight will be active:
    - laradock path presence
    - compose file presence
    - target container presence and running state
  - Docker-lite compose preflight strict mode (`PLUME_DOCKER_LITE_COMPOSE_REQUIRED`) will be preserved.
- Rationale:
  - Dry-run and rollback behavior must be deterministic for safe operations under mode parity.
  - Prefer early, clear fail-fast over ambiguous runtime errors in Laradock integration.
- Impact:
  - Strict/preflight and rollback tests become mandatory in Phase-05 scope.
  - Strict/dry-run rules are added to ops runbook and env-contract docs.

## 2026-03-07 - D-023 - Phase 4 Closeout (Project Init + Manifest Baseline)

- Status: accepted
- Decision:
  - The `project` command family left Phase-4 placeholder status; `project init` was activated.
  - `project init` baseline steps clarified: composer install, `.env` bootstrap, artisan key/storage steps, optional migrate/seed and npm steps.
  - `plume.yml` phase-4 baseline contract finalized: project-local `mode` resolution + invalid mode fail-fast.
- Rationale:
  - The Phase-4 goal of adding a Laravel project to the system in the fewest steps is completed by `site` + `project init` together.
  - At phase closure, test and docs evidence must match gate criteria.
- Impact:
  - Phase-4 checklist/gate items close; tracker moves the phase to `done`.
  - Broader `plume.yml` schema (service/site details) stays a controlled backlog for later phases.

## 2026-03-07 - D-024 - Phase 6 Native Service Runtime Contract

- Status: accepted
- Decision:
  - For native mode, the service runtime contract became file-based:
    - runtime state: `services_runtime_native.env`
    - allocated ports: `services_ports_native.env`
    - logs: `~/.config/plume/logs/services/native/<service>.log`
  - Added `running`, `health`, `port` fields to `services status` output.
  - Added `services health` and `services logs` commands.
  - For port-using services, if the default port is taken, apply a `+1..+50` fallback range.
- Rationale:
  - Native orchestration needs deterministic lifecycle observation and debuggability.
  - Before full systemd integration, a testable runtime abstraction layer is needed.
- Impact:
  - Phase-6 implementation/test/docs gate items close.
  - Phase-7/8 docker-lite and laradock runtime contracts align to this contract.

## 2026-03-07 - D-025 - Phase 7 Docker-Lite Runtime Parity

- Status: accepted
- Decision:
  - Docker-lite service adapters completed with compose-based lifecycle (`pull/up/stop`).
  - Added `services workspace up|down|status --mode=docker-lite`.
  - For docker-lite, `health` and `logs` flows were wired via compose `ps/logs` integration.
  - Compose strict-mode behavior preserved: if `PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true`, compose is mandatory fail-fast; otherwise stub fallback continues.
- Rationale:
  - Provide operational parity with the same command surface between native and docker-lite.
  - Progress without breaking backward compatibility in environments without Docker/dev setups.
- Impact:
  - Phase-7 checklist/gate closes.
  - Reference behavior is defined for the Phase-8 laradock bridge runtime contract.

## 2026-03-08 - D-026 - Docker-Lite Template Baseline + Image Suggestion Preflight

- Status: accepted
- Decision:
  - Added `templates/docker-lite/docker-compose.template.yml`.
  - Laradock-inspired lightweight model includes `workspace`, `nginx|apache2|caddy`, and `php81|php82|php83|php84-fpm` clone services in the template.
  - `services workspace up --mode=docker-lite` image preflight was expanded to print similar-image suggestions when an image is missing.
- Rationale:
  - Give users a customizable docker-lite baseline they can start with directly.
  - Prefer early guided errors over ambiguous docker errors when an image/tag is broken.
- Impact:
  - Docker-lite onboarding speeds up; compose and service mapping contract becomes clearer.
  - Groundwork for Phase-8 laradock-bridge template/sync decisions.

## 2026-03-08 - D-027 - Docker-Lite Workspace Stub Generator + Dynamic Default PHP

- Status: accepted
- Decision:
  - Added `services workspace init --mode=docker-lite --path=<dir>`.
  - The command creates a docker-lite stub in the target directory:
    - `docker-compose.yml`
    - `docker-lite/{nginx,apache2,caddy}` config files
    - `.env.docker-lite`
  - Default PHP runtime `php-fpm` service became dynamic:
    - `PLUME_DOCKER_LITE_PHP_DEFAULT_VERSION`
    - `PLUME_DOCKER_LITE_PHP_FPM_IMAGE`
  - Clone models (`php81-fpm`, `php82-fpm`, `php83-fpm`, `php84-fpm`) were kept in the template.
- Rationale:
  - Give users a "working docker-lite baseline in one command in the desired directory".
  - Allow runtime selection via the PHP default version variable without fixed config edits.
- Impact:
  - `.env`/template synchronization strengthened.
  - Docker-lite control flow became fast and repeatable via plume commands.

## 2026-03-08 - D-028 - Docker-Lite Port Policy Alignment with Native

- Status: accepted
- Decision:
  - Native-like port allocation/fallback was enabled in the docker-lite service start flow.
  - Default web behavior was fixed as a single active web server + host port `80`.
  - Separate 808x assumptions for `nginx/apache2/caddy` were removed; all were moved to the `PLUME_WEB_PORT` (default 80) base.
- Rationale:
  - Port management behavior parity between native and docker-lite modes.
  - Reduce unnecessary port distribution and confusion in default use.
- Impact:
  - Docker-lite status/state outputs begin showing port fallback results.
  - Single-webserver assumption in orchestration becomes clear; multi web server use is left to explicit profile selection.

## Template

- `YYYY-MM-DD - D-XXX - Title`
- Status: proposed | accepted | deprecated
- Decision:
- Rationale:
- Impact:

## 2026-03-10 - D-029 - Docker-Lite Beta Freeze and Phase-08 Priority Shift

- Status: accepted
- Decision:
  - Docker-lite phase moved to `beta-frozen`; remaining lightweight/local+production ergonomics work moved to backlog.
  - Active development focus shifted to Phase-08: `laradock-bridge` adapters reaching parity with the native command surface.
  - Native + laradock-bridge behavior unity was set as the near-term main delivery criterion.
- Rationale:
  - Docker-lite has not yet reached the target "one-roof light local/prod" experience; producing value quickly on the working Laradock ecosystem is more efficient than pushing further here.
  - Managing an already-running Laradock service topology via plume commands reduces user-value and adoption risk.
- Impact:
  - Phase-07 closure status revised from `done` to `beta-frozen`.
  - Phase-08 moved to `in-progress` and test/docs priority updated to laradock-bridge + native parity.
  - Docker-lite changes will be kept regression-free; new major work remains out of scope.

## 2026-03-10 - D-030 - Laradock Bridge Bootstrap Commands (init/sync/check)

- Status: accepted
- Decision:
  - Added `services laradock init|sync|check --mode=laradock-bridge` command family.
  - `init` clones/pulls the default Laradock repo (`https://github.com/laradock/laradock.git`) and supports a custom origin via `--repo`.
  - `sync` standardizes the branch/repo-based git fetch/pull flow.
  - `check` applies strict guards:
    - is the required service list present in compose
    - is `APP_CODE_PATH_CONTAINER=/var/www` in `.env`
    - is `APP_CODE_PATH_HOST` resolvable
    - do laradock-bridge mode site paths fall outside host scope
- Rationale:
  - Need for fast, safe integration with existing systems already running on Laradock.
  - Guarantee the same command surface as native in bridge mode with fail-fast preflight.
- Impact:
  - Discovery + compatibility guard items in the Phase-08 implementation checklist became active/progressed.
  - `mode path set/get laradock-bridge` flow gained direct use with laradock bootstrap commands.

## 2026-03-24 - D-031 - Readiness Baseline Clarification for Native and Laradock-Bridge

- Status: accepted
- Decision:
  - As of 2026-03-24, mode-based real readiness status was officially clarified and recorded in a separate status note:
    - `implementation/11-status-2026-03-24.md`
  - `docker-lite` remains outside active development.
  - For `native`, current status is accepted as "command surface + stateful orchestration"; not full host provisioning.
  - For `laradock-bridge`, current status is accepted as "bootstrap + strict preflight"; not full runtime lifecycle parity.
- Rationale:
  - Later threads or contributor changes should not over-assume current capabilities.
  - Next implementation steps for native and laradock-bridge should proceed from clear technical reality.
- Impact:
  - Later Phase-08 and native parity work will be planned against this readiness baseline.
  - For targets such as `workspace`, `phpmyadmin`, `redis-webui`, `php-worker`, `horizon`, the "surface exists / real runtime does not" split will be preserved.

## 2026-03-24 - D-032 - Laradock Runtime Context Must Be Explicit + Live Compose Wins

- Status: accepted
- Decision:
  - `laradock-bridge` runtime commands (`services status|health|logs|up|down|exec|containers`) run only with an explicit Laradock context.
  - Laradock path precedence:
    - `--path`
    - `mode path set laradock-bridge ...`
  - Runtime path is not guessed; without a path setting the command fails fast.
  - Laradock runtime source-of-truth is live `docker compose` state; state env files and SQLite are only a cache/telemetry layer.
- Rationale:
  - Remove the risk of touching the wrong Laradock directory.
  - In bridge mode, base on real container state and reduce state drift.
- Impact:
  - `services` commands do not run without Laradock path validation.
  - Phase-08A implementation moves status/health/logs/up/down commands onto a live compose base.

## 2026-03-24 - D-033 - Laradock Bridge State Sync Uses Live Compose as Cache Source

- Status: accepted
- Decision:
  - Added `sync state --mode=laradock-bridge`.
  - Before `services status --mode=laradock-bridge`, live compose -> state reconcile is triggered.
  - Reconcile flow:
    - running state
    - live port metadata
    - `services_runtime_laradock-bridge.env`
    - `services_ports_laradock-bridge.env`
    - `plume-state.db`
- Rationale:
  - Reduce state drift even if the user acts on docker outside plume.
  - Make the status screen rely on live runtime instead of a stale cache.
- Impact:
  - Laradock bridge status outputs become more consistent with SQLite/cache.
  - Bridge sync/state mapping item in Phase-08 is considered complete.

## 2026-03-25 - D-034 - Mode-Isolated Service Enabled Semantics

- Status: accepted
- Decision:
  - The `enabled` field is not computed from the same source in all modes.
  - For `native` and `docker-lite`, `enabled` = Plume env toggle/config.
  - For `laradock-bridge`, `enabled` = whether the related service exists in Laradock compose.
  - In Laradock, `nginx/apache2/caddy` health/status calculations are read from separate compose services.
- Rationale:
  - Forcing Laradock's existing stack into env-toggle logic caused wrong views and cross-mode confusion.
  - Each mode's service-management semantics must rest on its own engine reality.
- Impact:
  - `services status` outputs become more correct and clearer by mode.
  - In Laradock mode, the user clearly sees services present in compose; they do not mix with native/docker-lite state.

## 2026-03-25 - D-035 - Laradock Runtime Uses Full Compose Service Discovery

- Status: accepted
- Decision:
  - In `laradock-bridge` mode, the service list is not limited to a static Plume baseline.
  - `services supported`, `services status`, `services up all`, `services down all` discover all services from the active Laradock `docker-compose.yml`.
  - Plume aliases are preserved:
    - `php` -> `php-fpm`
    - `composer` -> `workspace`
    - `horizon|supervisor` -> `laravel-horizon`
- Rationale:
  - Users want to see and manage all services under Laradock; a static support list is insufficient.
  - The purpose of bridge mode is to adapt the existing Laradock stack as-is.
- Impact:
  - Laradock status/supported output rests on compose reality.
  - Sync/runtime state files begin storing raw compose service names in Laradock.

## 2026-03-25 - D-036 - Laradock `all` Lifecycle Uses Desired Service Set

- Status: accepted
- Decision:
  - In Laradock, `services up all` and `services down all` no longer target every service in compose.
  - The target service set is kept in the SQLite `desired_services` table.
  - New command family:
    - `services config show --mode=laradock-bridge`
    - `services config add <service|@group> --mode=laradock-bridge`
    - `services config remove <service|@group> --mode=laradock-bridge`
    - `services config reset --mode=laradock-bridge`
  - Group targets (`@core`, `@web`, `@db`, `@queue`) can be written into the desired set.
- Rationale:
  - Users want to manage the service set they actually need for the project, not every Laradock service.
  - Having `all` affect everything in compose is too broad and risky for production/local parity.
  - An SQLite-based desired set is more reliable and queryable than a flat file.
- Impact:
  - Laradock lifecycle becomes more controlled.
  - `services status/supported` continue showing compose reality; `up/down all` run according to desired config reality.

## 2026-04-03 - D-037 - Laradock `up all` Safe Ordering + Rollback

- Status: accepted
- Decision:
  - `services up all --mode=laradock-bridge` runs the resolved service set in safe-order:
    - `db -> php -> queue -> web -> others`
  - `services down all --mode=laradock-bridge` runs in reverse safe-order:
    - `web -> queue -> php -> db -> others`
  - If a service start fails during `up all`, services started earlier in the same command are rollback-stopped in reverse order.
- Rationale:
  - Random start/stop order in existing Laradock stacks produced race conditions and dependency errors.
  - A half-active system must not be left after a failed partial bring-up.
- Impact:
  - `laradock-bridge` lifecycle behavior became more deterministic.
  - Failure rollback reduces the need for manual cleanup on partial starts.

## 2026-04-03 - D-038 - Adapter Contract Normalization Across Modes

- Status: accepted
- Decision:
  - Mode-independent aliases are normalized in the `services` command family:
    - `php-fpm -> php`
    - `workspace -> composer`
    - `php-worker -> php_worker`
    - `laravel-horizon -> horizon`
  - This normalization is applied in the `service exists`, target resolve, version validate, and callback invoke chain.
- Rationale:
  - Users should work with the same service names on the command surface without thinking about mode.
  - The name contract must be deterministic for the same command surface goal between native and laradock-bridge.
- Impact:
  - Alias-sourced "unknown service" errors decrease.
  - The `native<->laradock-bridge adapter contract normalization` item in Phase-08 closes.

## 2026-04-03 - D-039 - Bridge Port/State Introspection Uses Multi-Port Snapshot

- Status: accepted
- Decision:
  - `sync state --mode=laradock-bridge` now writes all host ports published on the container into state, not just one host port.
  - For web services (`nginx/apache2/caddy/openresty`), the `web_https` key is also synced from the 443 map.
- Rationale:
  - In Laradock stacks, `workspace` and similar services publish multiple ports.
  - A single-port snapshot left operational visibility incomplete.
- Impact:
  - `services_ports_laradock-bridge.env` and the state DB carry a more accurate runtime port view.
  - Phase-08 `port/state introspection` item closes.

## 2026-04-03 - D-040 - Safe Interop Defaults + Cross-Mode Command Surface Equivalence

- Status: accepted
- Decision:
  - In `laradock-bridge` mode, `up/down all` behavior remains non-destructive by default:
    - only the desired/resolved set is targeted
    - compose services outside desired are unaffected
  - Adapter contract aliases work the same way in native and laradock-bridge modes:
    - `php-fpm`, `workspace`, `php-worker`, `laravel-horizon`
- Rationale:
  - Accidentally affecting non-plume services in existing Laradock stacks is a critical risk.
  - Changing command names when mode changes increases operational error likelihood.
- Impact:
  - Phase-08 scope checklist items
    - `Safe interoperability and no destructive defaults`
    - `Command equivalence with native`
    close.

## 2026-04-03 - D-041 - Phase 09 Start: Observability-First Ops Baseline

- Status: accepted
- Decision:
  - Phase-09 started as `in-progress`.
  - First delivery slice focuses on the `doctor/monitor` base contract:
    - `doctor check`
    - `doctor services`
    - `doctor ports`
  - `status/health/logs --watch` outputs are used as a telemetry layer for production-ops.
  - On critical failure, fail-fast + audit event recording is mandatory.
- Rationale:
  - Runtime parity was completed with Phase-08; visibility and risk surfacing are the next critical layer for production operations.
- Impact:
  - Phase-09 backlog advances along monitorability, security checks, cert/secrets, and recovery runbook axes.

## 2026-04-03 - D-042 - Doctor Baseline Routed and Test-Gated

- Status: accepted
- Decision:
  - The `doctor` command family was wired into the CLI main router and added to help output.
  - Subcommand contract clarified:
    - `doctor check [--mode=...] [--deep]`
    - `doctor services [--mode=...]`
    - `doctor ports [--mode=...]`
  - Baseline behaviors were placed under a test-gate via `tests/phase9_doctor_smoke.sh`.
- Rationale:
  - Entering the Phase-09 observability layer requires the command surface to be visible and testably fixed.
  - Commands not wired into the router create docs mismatch and regression risk.
- Impact:
  - `doctor` commands are now reachable in the standard command flow.
  - Minimum smoke coverage formed for fast validation in the first Phase-09 slice.

## 2026-04-03 - D-043 - Ops Wrapper Commands + Runtime Audit Events

- Status: accepted
- Decision:
  - Top-level `status`, `health`, `logs` commands were activated and wired as wrappers to related `services` commands.
  - New `monitor` command family added:
    - `monitor summary`
    - `monitor watch`
    - `monitor events`
  - For these commands, writing `ops.*`-prefixed audit events to the state DB `runtime_events` table became mandatory.
- Rationale:
  - Phase-09 operational visibility needs a single-command monitoring flow and a command-audit trail.
  - The upper command surface should stay simple for users who do or do not know `services` subcommands.
- Impact:
  - The observability command family became directly usable.
  - Traceability of recent operations via `monitor events` is provided through the state DB.

## 2026-04-03 - D-044 - Monitor Summary Failure Scoring + Strict Exit

- Status: accepted
- Decision:
  - Added a service-scan-based scoring model for `monitor summary`:
    - `OVERALL=OK|WARN|FAIL`
    - `CRITICAL`, `WARN`, `RUNNING`, `HEALTHY` counters
    - issue list (`service: running=..., health=...`)
  - With `--strict`, if `CRITICAL>0`, the command returns exit code `2`.
- Rationale:
  - Critical issues need a one-line overall signal rather than staying only as table rows.
  - CI/ops automation requires a deterministic non-zero exit in critical cases.
- Impact:
  - `monitor summary` became both human-readable and actionable for automation.

## 2026-04-03 - D-045 - Critical Command Guard Policy (`--yes`) + Audit Trail

- Status: accepted
- Decision:
  - Explicit `--yes` confirmation is required for these critical commands:
    - `mode use --force`
    - `mode path set|clear --force`
    - `services workspace reinit`
    - `services update`
  - Guard results are audited into the `runtime_events` table on every call:
    - `critical.<operation>.blocked`
    - `critical.<operation>.approved`
- Rationale:
  - Accidentally changing context/path or resetting workspace has high impact.
  - Without an audit trail, backtracking and incident analysis get harder in production-like environments.
- Impact:
  - Accidental execution risk for critical commands decreases.
  - An auditable, consistent approval trail is formed.

## 2026-04-03 - D-046 - Recovery Runbook Command Surface (`monitor runbook`)

- Status: accepted
- Decision:
  - Added `monitor runbook` and standardized command-focused recovery flows.
  - Supported scenarios:
    - `incident`
    - `recovery`
    - `ports-conflict`
  - Operations doc `docs/operations/incident-triage-runbook.md` was aligned with the command chain.
- Rationale:
  - During incidents, a deterministic step list is needed instead of random command selection.
  - For the "runbooks wired to commands" goal, docs + CLI output contract must exist together.
- Impact:
  - Recovery flows are reachable with one command.
  - The incident triage doc became directly compatible with the CLI.

## 2026-04-03 - D-047 - Backup Baseline (`backup create/list/show/restore`) + Guarded Restore

- Status: accepted
- Decision:
  - Activated the `backup` command family:
    - `backup create`
    - `backup list`
    - `backup show`
    - `backup restore`
  - Restore is treated as critical and placed under `--yes` guard (except `--dry-run`).
  - Backup/restore and guard events are written to runtime audit:
    - `backup.create.ok`
    - `backup.restore.ok`
    - `critical.backup.restore.(blocked|approved)`
- Rationale:
  - Phase-09 operational recovery capability needs a minimum restoreable baseline.
  - Preventing wrong restore calls and recording events is mandatory for production hygiene.
- Impact:
  - Config/state restore flow became usable at CLI level.
  - Security+backup docs set was aligned with command behavior.

## 2026-04-03 - D-048 - Rollback/Failback Baseline via `deploy` + Backup Integration

- Status: accepted
- Decision:
  - Activated baseline rollback in the `deploy` command family:
    - `deploy plan`
    - `deploy rollback <id|latest>`
    - `deploy failback`
  - `deploy rollback` automatically creates a failback point before restore.
  - `deploy failback` restores the latest failback point.
  - Rollback/failback placed under critical command guard (`--yes`, except dry-run).
- Rationale:
  - Production-like flows need a one-command revert mechanism.
  - A failback point is mandatory to step back one more time after an unexpected post-rollback state.
- Impact:
  - Phase-09 rollback/failback goal became usable at command level.
  - Audit trail covers deploy revert events (`deploy.*`, `critical.deploy.*`).

## 2026-04-03 - D-049 - Security Baseline Command Surface (`security check` + `security secrets`)

- Status: accepted
- Decision:
  - Added new `security` command family:
    - `security check` (OS/firewall preflight snapshot)
    - `security secrets list|get|set|unset|generate`
  - Secret store is managed on `secrets.env` under the state directory (mode-agnostic, local baseline).
  - Security/secrets operations are written to runtime audit (`security.*`).
- Rationale:
  - Phase-09 secret management and OS security checks need a minimum CLI baseline.
  - Without a repeatable, traceable secret operations surface, the adapter/server layer cannot progress safely.
- Impact:
  - Secret management baseline and firewall preflight completed at command level.
  - A security-focused command set formed for ops teams beyond `doctor/monitor`.

## 2026-04-03 - D-050 - Project `.env` Secret Sync Bridge (`project env sync-secrets`)

- Status: accepted
- Decision:
  - Added `project env sync-secrets`.
  - Source: `$(plume_state_dir)/secrets.env`
  - Target: `<project>/.env`
  - Supported behaviors:
    - selected key sync (`--keys=K1,K2`)
    - sync all keys (when keys are omitted)
    - dry-run
    - if `.env` is missing, create it from `.env.example` with `--create-env`
  - Operation is recorded as a runtime event: `project.env.sync-secrets.ok`.
- Rationale:
  - The practical value of the secret baseline appears when keys are transferred safely/repeatably into a Laravel project `.env`.
  - Manual copy mistakes must be reduced and flows moved toward repeatable provisioning.
- Impact:
  - Keys stored with `security secrets` can be synced with one command before project onboarding/deploy.

## 2026-04-03 - D-051 - TLS Baseline with Multi-Domain Local Cert Flow (`security cert`)

- Status: accepted
- Decision:
  - Added `security cert` subcommands:
    - `issue --domains=d1,d2 [--days=30] [--name=id]`
    - `list`
    - `show <id>`
    - `renew <id> [--days=30]`
  - Certificate artifacts are written under state: `$(plume_state_dir)/certs/<id>/`.
  - Multi-domain SAN (`subjectAltName`) is preserved through cert issue/renew flows.
  - Events are written to runtime audit (`security.cert.*`).
- Rationale:
  - Phase-09 TLS/certificate goal needs a repeatable local baseline with minimal dependency (openssl).
  - Multi-domain cert needs (site/domain parity) require SAN-based cert generation.
- Impact:
  - Cert issue/renew lifecycle became testable and traceable at CLI level.

## 2026-04-03 - D-052 - Site-Level TLS Binding (`site --cert-id`) and HTTPS Snippet Rendering

- Status: accepted
- Decision:
  - Added `--cert-id` and `--https-port` fields to `site add|update`.
  - When `cert_id` is set, site publish render becomes HTTPS-focused:
    - nginx: HTTP->HTTPS redirect + `listen <https_port> ssl` + cert/key
    - apache2: HTTP vhost redirect + SSL VirtualHost + cert/key
    - caddy: `tls <crt> <key>`
  - Cert artifact presence is validated before publish.
- Rationale:
  - Operational value of cert generation appears only with site-level binding.
  - Mode parity requires consistent TLS render across web server adapters.
- Impact:
  - Certs produced by `security cert` can be used directly by site lifecycle commands.
  - `cert_id` and `https_port` visibility provided in site check/list output.

## 2026-04-03 - D-053 - Phase 09 Closure: Ops/Security/Recovery Baseline Completed

- Status: accepted
- Decision:
  - Phase-09 gate items completed and the phase closed as `done`.
  - Scope completed: observability suite, TLS baseline, secrets baseline, rollback/failback, backup scope, security/firewall checks.
- Rationale:
  - The command/docs/test triad for phase goals completed and the smoke chain runs stably.
- Impact:
  - A clear starting point for Phase-10 focused on stabilization and adapter-readiness.

## 2026-04-03 - D-054 - Phase 10 Kickoff with Single-Command E2E Matrix Baseline

- Status: accepted
- Decision:
  - Phase-10 started as `in-progress`.
  - Added `tests/phase10_e2e_matrix_smoke.sh`; native + laradock-bridge baseline + docker-lite beta-frozen regression checks gathered into one command.
  - Pre-release operational no-go criteria standardized via `docs/operations/release-readiness.md`.
  - CLI output contract doc expanded with phase-10 text-table stabilization rules.
- Rationale:
  - Phase-10 stabilization/release readiness needs scattered smoke commands gathered into one entrypoint.
  - Text/json output rules must be explicit to reduce adapter-side parse breaks.
- Impact:
  - Release quality gate became more consistent and repeatable.
  - Parse contract clarified before Plume-adapter onboarding.

## 2026-04-03 - D-055 - Phase 10 Closure: Stabilization + Release + Adapter Baseline Completed

- Status: accepted
- Decision:
  - Phase-10 checklist items closed and the phase set to `done`.
  - E2E matrix chain, rollback regression, and install-to-operate journey tests were added to the release chain.
  - Release versioning/tag policy and adapter onboarding docs were made durable.
- Rationale:
  - For Plume's current scope, the release-ready baseline and adapter-integration context are now consistent across docs+tests+decisions.
- Impact:
  - First cycle of the phased roadmap completed; next steps (golden contract snapshots, CI matrix) cleanly separated into backlog.

## 2026-04-03 - D-056 - Phase 11 Kickoff: Native Adapter Contract Parity

- Status: accepted
- Decision:
  - New phase opened: `Phase 11 - Native Adapter Contract Parity`.
  - Priority is a Laradock-like single-contract experience in native mode:
    - service alias/semantic parity
    - site+php runtime parity
    - horizon/supervisor lifecycle parity
    - mariadb/mysql/redis/phpmyadmin operational parity
- Rationale:
  - User expectation is a mode-agnostic single-command experience; native mode must feel as consistent as docker/laradock.
- Impact:
  - Development focus shifted from docker-lite (beta-frozen) to deepening the native adapter contract.

## 2026-04-03 - D-057 - Native Alias Contract Regression Baseline (Phase-11 Slice-1)

- Status: accepted
- Decision:
  - Adapter-alias behavior for native mode was locked with a regression test:
    - `php-fpm -> php`
    - `workspace -> composer`
    - supervisor dependency guard on `laravel-horizon` calls
  - New test: `tests/phase11_native_adapter_contract_smoke.sh`
- Rationale:
  - The first breakage point for "mode-agnostic single-command experience" is alias semantics; locking it early makes later parity work safer.
- Impact:
  - A safe baseline formed for profile/site/php/db parity changes in later Phase-11 slices.

## 2026-04-03 - D-058 - Core Service Parity Lock (Phase-11 Scope Freeze)

- Status: accepted
- Decision:
  - For Phase-11, 1:1 parity was locked first on these core services:
    - `php(fpm)`
    - `nginx/caddy/apache2`
    - `mariadb/mysql`
    - `phpmyadmin`
    - `laravel-horizon` (+ supervisor dependency)
    - `redis`
  - New smoke test for this scope:
    - `tests/phase11_native_core_services_parity_smoke.sh`
- Rationale:
  - User priority is 1:1 mode-agnostic adapter behavior on these services.
  - Other services will not enter the roadmap before this core set is complete.
- Impact:
  - Phase-11 development order clarified; scope scatter prevented.

## 2026-04-03 - D-059 - Native PHP Matrix Structure (Default + Custom Versions)

- Status: accepted
- Decision:
  - Real `php` command family added:
    - `php list`
    - `php install <version>`
    - `php use <version|alias>`
    - `php alias list|set|default`
  - Native PHP matrix configuration is written to a durable state file:
    - `~/.config/plume/state/php.env` (or `PLUME_STATE_DIR/php.env`)
  - `php install` auto-creates a canonical alias (`8.4 -> php84`).
  - `php use` makes the selected version default and adds it to the installed list if needed.
- Rationale:
  - Native mode needs durable, adapter-friendly management of main/default PHP and extra custom PHP versions.
  - Without this, `services up php --version=<alias|version>` behavior was not repeatable.
- Impact:
  - Native mode PHP version selection is now manageable and durable at command level.
  - Groundwork formed for site/php runtime contract hardening in the Phase-11 parity flow.

## 2026-04-03 - D-060 - Safe Mode Switch from Laradock-Bridge to Native (`--down-running`)

- Status: accepted
- Decision:
  - Added `--down-running` option to `mode use`.
  - If current mode is `laradock-bridge` and containers are running:
    - without `--down-running`, the switch is blocked with a clear guidance message.
    - with `--down-running`, plume runs `docker compose down` in the related compose context and then switches mode.
- Rationale:
  - Reduce port conflict and half-left runtime state risk when switching to native mode.
- Impact:
  - Users get a controlled, deterministic switch path.
  - Mode-switch safety strengthened for Phase-11 parity flows.

## 2026-04-03 - D-061 - Global Native Env Model (System-Level `.env`)

- Status: accepted
- Decision:
  - Default env source became the global plume env instead of a project-local `.env`:
    - `~/.config/plume/.env` (override: `PLUME_GLOBAL_ENV_FILE`)
  - If global env is missing, bootstrap:
    - first `~/.config/plume/.env.example`
    - else `.env.example` in the working directory
  - Explicit `PLUME_STATE_DIR` and `PLUME_LOG_DIR` values given at runtime are not overridden by the env-file step.
- Rationale:
  - Native mode system orchestration needs a single global env contract similar to docker-compose.
  - Goal was to remove the need to pass `--env-file` on every command.
- Impact:
  - Native mode configuration can now be managed from one system-level point.
  - Explicit state directory guarantees are preserved for test/runtime isolation.

## 2026-04-03 - D-062 - Global Env Commands (`env where|init`) for Native Operations

- Status: accepted
- Decision:
  - New command family added:
    - `env where`
    - `env init [--force] [--from=/path/.env.example]`
  - These commands become the standard path to discover/init the global native env file (`~/.config/plume/.env`).
- Rationale:
  - In native mode system orchestration, users should not keep passing `--env-file`, and env location should be deterministic.
- Impact:
  - Install flow simplified: `env init` + normal plume commands.
  - On the adapter side, the env discover/init step can be automated with one command.

## 2026-04-03 - D-063 - Built-in Native Core `.env.example` Template

- Status: accepted
- Decision:
  - Built-in native core env template added to the Plume repository:
    - `templates/native-core.env.example`
  - Built-in template included in the `env init` and default global env bootstrap source order.
- Rationale:
  - Users should be able to quickly start a core stack like php/nginx/mariadb/redis/horizon without writing env from scratch every time.
- Impact:
  - Native mode onboarding speed increases.
  - `env init` can now run based on the ready profile inside the repository.

## 2026-04-03 - D-064 - Service Contract PHP Target Alias Normalization + Env Override Precedence

- Status: accepted
- Decision:
  - Single-target normalize/resolve flow in `services` commands was expanded:
    - targets like `php84`, `php82`, `php-fpm-8.4` normalize to the canonical `php` service.
    - PHP version is auto-resolved from the target and `up/status/health/logs` flows run with that version.
  - Laradock bridge `php` service mapping can redirect to an existing `php-fpm-<version>` service when a target PHP version is given (`PLUME_SERVICE_VERSION`).
  - `plume_load_env` updated:
    - externally provided `PLUME_*` and `PMA_*` env values are not overwritten during the global `.env` source step while a command runs.
- Rationale:
  - Users expect a mode-independent single adapter-contract experience.
  - Being able to pass PHP matrix targets directly from the service name (`php84`) simplifies operations UX.
  - Global env source was breaking command-scope overrides and creating test/ops chaos.
- Impact:
  - `services up/status/health/logs` are more consistent and deterministic for PHP alias targets.
  - Contract alignment strengthened in the native/laradock bridge parity step.
  - Env precedence model became safer (CLI override > global env).

## 2026-04-03 - D-065 - Native Host PHP Version Shims (`php8.4` / `php-fpm-8.4`)

- Status: accepted
- Decision:
  - Added `php shim` command family:
    - `php shim install`
    - `php shim env`
    - `php shim list`
    - `php shim remove`
  - Shim install produces executable wrapper files from `PLUME_PHP_INSTALLED_VERSIONS`:
    - `php8.4`, `php84`
    - `php-fpm-8.4`, `php-fpm84`
  - Wrapper commands find and exec the target version binary on the host via `php shim run`.
  - Default `php` binary behavior is unchanged; only versioned commands are activated.
- Rationale:
  - User expectation: run `php8.4 -v` and `php-fpm-8.4 -v` directly in the terminal.
  - At the same time, the default native `php` command must stay aligned with current host settings.
- Impact:
  - Laradock-like multi-PHP experience strengthened at CLI level for native mode parity.
  - Versioned PHP/FPM call scenarios became PATH-based, portable, and reversible.

## 2026-04-03 - D-066 - `init shell` Idempotent Bootstrap for PHP Shims

- Status: accepted
- Decision:
  - New command added: `init shell`
    - `--shell=zsh|bash`
    - `--rc=/path/to/rc`
    - `--force`
  - The command first runs `php shim install`, then idempotently writes this block into the target rc file:
    - `# >>> plume php shim >>>`
    - `eval "$(<plume-exec> php shim env)"`
    - `# <<< plume php shim <<<`
  - Re-running does not create a duplicate block; `--force` refreshes the block.
- Rationale:
  - Users want versioned commands (`php8.4`, `php-fpm-8.4`) on every terminal open without a manual `eval`.
  - Automatic, safe setup is needed without breaking default `php` behavior.
- Impact:
  - Onboarding reduced to one command: `./plume.sh init shell`.
  - A deterministic, reversible model provided for shell integration.

## 2026-04-03 - D-067 - Multi-Version Shell Alias Export (zsh/bash Compatible)

- Status: accepted
- Decision:
  - `php shim env` output scope expanded:
    - in addition to the PATH export line, alias lines are printed for all installed non-default PHP versions.
    - Format:
      - `alias php81='php8.1'`
      - `alias phpfpm81='php-fpm-8.1'`
  - No alias is produced for the default PHP version; the `php` command remains the host native default.
- Rationale:
  - Fast, shell-native shortcuts are needed when different PHP versions are used across projects on the same machine.
  - A shared, portable alias model is targeted for zsh and bash.
- Impact:
  - Users can use shortcuts like `php81`, `php82`, `php84`, `phpfpm81` directly in the shell.
  - Multi-version UX improved without breaking default `php` behavior.

## 2026-04-03 - D-068 - `doctor php` Diagnostics for Binary Compatibility

- Status: accepted
- Decision:
  - New subcommand added: `doctor php [--strict]`.
  - For each version in `PLUME_PHP_INSTALLED_VERSIONS`, the command reports as a table:
    - CLI binary presence
    - FPM binary presence
    - role (`default|extra`)
  - In `--strict` mode, any version missing cli/fpm binary returns `exit 2`.
- Rationale:
  - Need proactive visibility into hanging or not-found cases for shim commands like `php8.4`/`php-fpm-8.4`.
  - Fast compatibility audit is needed in multi-project multi-version environments.
- Impact:
  - Operational troubleshooting sped up.
  - A fail-fast checkpoint added in the shell shim + native php matrix model.

## 2026-04-03 - D-069 - Native `services install php` -> Real Host Binary Provisioning

- Status: accepted
- Decision:
  - In native mode, `services install php --version=<x.y>` now attempts real host install, not only a state hook.
  - Install driver model:
    - macOS: `brew install php@x.y`
    - Linux (apt): `apt install phpx.y-cli phpx.y-fpm`
    - Linux (dnf): currently manual guidance (version-specific automation backlog)
  - After install, cli/fpm binary presence is verified.
  - On successful install, the version is auto-recorded into php matrix state (`php.env`) and the alias set is updated.
  - Install privilege semantics made OS-aware:
    - Linux: root/sudo required
    - macOS+brew: normal user required instead of root
- Rationale:
  - User expectation is that the php version matrix is truly provisioned onto the host by plume.
  - Close missing binaries from `doctor php --strict` reports directly via `services install php`.
- Impact:
  - Native mode parity level increased; php service contract gained provisioning ability.
  - In multi-project different-PHP-version scenarios, plume offers install + register + check in one command flow.

## 2026-04-03 - D-070 - Native `services up php` Auto-Provision for Missing Versions

- Status: accepted
- Decision:
  - Native `services up php --version=<x.y>` flow expanded:
    - if the target version is missing from the php matrix or host cli/fpm binary is missing, auto-provision triggers.
    - auto-provision steps:
      1. install privilege check (OS-aware)
      2. host package install attempt (`brew|apt|...`)
      3. cli/fpm binary verify
      4. php matrix state (`php.env`) register
    - then the normal start hook runs.
- Rationale:
  - User one-command expectation: `services up` both prepares and starts.
  - Tying version switches to a manual install step in multi-project environments increases ops cost.
- Impact:
  - `services up php` became more self-healing and onboarding-friendly.
  - `services install php` remains an explicit provisioning command; `up` invokes it automatically when needed.

## 2026-04-03 - D-071 - PHP Extension Matrix (Per-Version Isolation + Auto-Sync)

- Status: accepted
- Decision:
  - Extension configuration added to the unified env contract:
    - `PLUME_PHP_EXTENSIONS_GLOBAL`
    - `PLUME_PHP_EXTENSIONS_81`, `PLUME_PHP_EXTENSIONS_82`, `...`
    - `PLUME_PHP_EXTENSIONS_STRICT`
    - `PLUME_PHP_EXTENSIONS_AUTO_SYNC`
    - `PLUME_PHP_EXT_INSTALL_DRIVER`
  - New commands:
    - `php ext sync <version|all> [--strict|--no-strict]`
    - `php ext doctor [--strict]`
    - `doctor php-ext [--strict]`
  - In the `services up php` flow, extension auto-sync runs after binary prep (via toggle).
- Rationale:
  - PHP extensions must be managed with per-version isolation; "install once, works everywhere" is not reliable.
  - Extension parity must be guaranteed when selecting different PHP runtimes per site.
- Impact:
  - Native multi-project/multi-version scenarios became deterministic at the extension level.
  - Pre/post-deploy extension compatibility can be fail-fast checked with `doctor php-ext --strict`.

## 2026-04-03 - D-072 - Native Site Upstream Resolution for Per-Version PHP-FPM

- Status: accepted
- Decision:
  - Native mode upstream resolve strengthened in the site publish pipeline:
    - per-version override env supported:
      - `PLUME_NATIVE_PHP_FPM_UPSTREAM`
      - `PLUME_NATIVE_PHP_FPM_UPSTREAM_<major><minor>`
    - if no override, try native socket auto-discovery:
      - Linux: `/run/php/phpX.Y-fpm.sock`
      - macOS: `/opt/homebrew/var/run/php@X.Y-fpm.sock` etc.
  - Server-specific render adaptation:
    - nginx: `fastcgi_pass unix:/...sock`
    - caddy: `php_fastcgi unix//...sock`
    - apache2: `SetHandler "proxy:unix:/...sock|fcgi://localhost/"`
- Rationale:
  - With project-based PHP runtime selection, webserver config must bind to the correct version-specific FPM endpoint.
  - Container names like `php82-fpm:9000` are not always valid in native mode.
- Impact:
  - Native mode site routing parity became more realistic and production-like.
  - Version isolation is also preserved at the webserver config level.

## 2026-04-04 - D-073 - PHP Extension Auto-Sync Profiles + Native Env Presets

- Status: accepted
- Decision:
  - `services up php` extension auto-sync behavior became profile-based:
    - `PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE=matrix|target|default`
    - default: `matrix`
  - Native preset env files added:
    - `templates/native-local.env.example` -> profile `matrix`
    - `templates/native-prod.env.example` -> profile `target`
  - Documentation updated:
    - `docs/commands/env.md`
    - `docs/commands/global.md`
    - `docs/commands/services.md`
    - `docs/commands/php.md`
    - `docs/operations/env-contract.md`
- Rationale:
  - Local environments want full matrix extension parity (dev ergonomics),
    while production prefers faster, lower-risk sync focused on the target version.
- Impact:
  - Profile-based, deterministic extension sync scope control while keeping the one-command experience.
  - Local/prod onboarding sped up; users can apply a preset directly with `env init --from=...`.

## 2026-04-04 - D-074 - Native Web Server Reload Validation Gate

- Status: accepted
- Decision:
  - Config validation gate added to the native `site publish --reload` flow:
    - nginx: `nginx -t`
    - apache2: `apachectl -t` or `httpd -t`
    - caddy: `caddy validate`
  - New env toggle:
    - `PLUME_SITE_RELOAD_VALIDATE=true|false` (default: `true`)
  - If validation fails, reload is skipped and the reload step is considered failed.
  - If `PLUME_SITE_RELOAD_REQUIRED=true`, the publish command fails fast (`exit 2`).
- Rationale:
  - Attempting reload with an invalid web server config destabilizes the runtime.
  - Fail-fast validation in site publish reliability is critical for production parity.
- Impact:
  - Native web server adapter behavior became safer and more deterministic.
  - Guaranteed that reload is not performed on bad configs.

## 2026-04-04 - D-075 - Native Nginx Strict Publish Pipeline

- Status: accepted
- Decision:
  - New strict toggle added:
    - `PLUME_SITE_NGINX_STRICT=true|false` (default: false)
    - `PLUME_NGINX_INCLUDE_DIR=/path` (optional explicit include target)
  - When strict is on for native `server=nginx` publish:
    1. rendered snippet is written to the real include target,
    2. `nginx -t` lint runs,
    3. reload runs,
    4. if lint/reload fails, the include file is rolled back.
  - In the site remove flow with strict on, the target include file is also removed; lint/reload is best-effort.
- Rationale:
  - Writing only to plume cache is not enough for real nginx runtime parity.
  - For production-like reliable publish, include target + lint + reload must be one operation.
- Impact:
  - Native nginx publish became more realistic and safer.
  - Automatic rollback on bad config/broken reload reduced outage risk.

## 2026-04-04 - D-076 - Site-Level PHP Upstream Override Contract

- Status: accepted
- Decision:
  - Added `--php-upstream=<host:port|unix:/sock>` to `site add/update`.
  - New field on the site record: `php_upstream`.
  - Upstream resolution in the render flow:
    - if `php_upstream` is set, use it directly.
    - if empty, produce via the existing resolver (`php_version` + mode/env contract).
  - `site check` output expanded:
    - `php_upstream`
    - `php_upstream_resolved`
- Rationale:
  - Project/site-based PHP routing needs cannot always be expressed by a version-only resolver.
  - Explicit override at `fastcgi_pass` level speeds migration and debug.
- Impact:
  - Site onboarding flow became more dynamic.
  - Per-site PHP upstream management and visibility increased.

## 2026-04-05 - D-077 - Strict Nginx Publish + `--reload` Dedup

- Status: accepted
- Decision:
  - Because the native `PLUME_SITE_NGINX_STRICT=true` publish pipeline already runs reload,
    the second reload step in `site publish --reload` is skipped.
  - Info message added to command output:
    - `site reload skipped: already reloaded in strict publish pipeline`
- Rationale:
  - A second reload in the same publish operation creates unnecessary ops load and log noise.
- Impact:
  - Strict publish behavior runs more deterministically with fewer side effects.

## 2026-04-05 - D-078 - Strict Publish Contract Extended to Apache2/Caddy

- Status: accepted
- Decision:
  - Native strict publish contract extended beyond nginx:
    - apache2: `PLUME_SITE_APACHE2_STRICT`, `PLUME_APACHE2_INCLUDE_DIR`
    - caddy: `PLUME_SITE_CADDY_STRICT`, `PLUME_CADDY_INCLUDE_DIR`
  - Strict pipeline for both servers:
    1. sync snippet to target include path,
    2. config lint,
    3. reload,
    4. rollback on fail.
  - Duplicate reload prevention is preserved when `site publish --reload` is used with strict.
- Rationale:
  - Leaving strict behavior only on nginx creates contract imbalance against the web server parity goal.
- Impact:
  - Native web server adapter contract became symmetric for nginx/apache2/caddy.

## 2026-04-17 - D-079 - Hybrid PHP Extension Contract (Preset + Toggle + Matrix)

- Status: accepted
- Decision:
  - Extension resolution layer moved to a hybrid model:
    - preset: `PLUME_PHP_EXT_PRESET`, `PLUME_PHP_EXT_PRESET_<ver>`
    - toggle: `PLUME_PHP_EXT_ENABLE_*`, `PLUME_PHP_EXT_ENABLE_<ver>_*`, `PLUME_PHP_EXT_DISABLE_<ver>_*`
    - matrix: `PLUME_PHP_EXTENSIONS_GLOBAL`, `PLUME_PHP_EXTENSIONS_<ver>`
  - Resolution order:
    - `preset + matrix + enable - disable`
    - disable toggle has the final say.
  - New command:
    - `php ext resolve <version|all>` (makes the final extension set observable)
- Rationale:
  - Matrix-only model is strong but weak for onboarding UX.
  - Boolean-toggle-only model is insufficient for advanced flexibility.
  - Hybrid model offers both easy start and advanced control.
- Impact:
  - Extension management became more adaptive and reusable across projects.
  - `services up php` auto-sync behavior runs deterministically on the same contract.

## 2026-04-25 - D-080 - Site Check Strict Visibility Contract

- Status: accepted
- Decision:
  - Strict publish visibility added to `site check` output:
    - `mode`
    - `strict_enabled`
    - `strict_include_dir`
    - `strict_include_target`
  - These fields exist in both text and JSON output contracts.
- Rationale:
  - During operational debug, "is strict active, which include target is used?" should be answered by one command.
- Impact:
  - Site-level diagnosability and mode-aware debug speed increase.
