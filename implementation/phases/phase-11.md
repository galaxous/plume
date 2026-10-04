# Phase 11 - Native Adapter Contract Parity

## Objective

- Bring native mode closer to a single-contract adapter layer that gives users a laradock/docker workflow feel.

## Status

- `done` (started: 2026-04-03, completed: 2026-07-25)
- Priority: high

## Scope Checklist

- [x] Core parity: `php (fpm)` (baseline)
- [x] Core parity: `nginx/caddy/apache2` (baseline)
- [x] Core parity: `mariadb/mysql` (baseline)
- [x] Core parity: `phpmyadmin` (baseline)
- [x] Core parity: `laravel-horizon` (+ supervisor) (baseline)
- [x] Core parity: `redis` (baseline)
- [x] Native service contract surface (laradock-like command semantics)
- [x] Native site lifecycle + php runtime selection parity hardening
- [x] Native queue/horizon/supervisor operational parity
- [x] Native DB stack parity (mariadb/mysql/redis/phpmyadmin) with adapter mapping

## Implementation Checklist

- [x] Adapter alias map v2 baseline regression locked (workspace/php-fpm/horizon parity)
- [x] Native PHP matrix command surface (`php list|install|use|alias`) + persisted state
- [x] Global native env command surface (`env where|init`) + bootstrap wiring
- [x] Built-in native core env example template (`templates/native-core.env.example`)
- [x] Native service profiles (`@core/@web/@db/@queue`) laradock-equivalent behavior
- [x] Site add/update/publish php runtime resolve contract stabilization
- [x] Horizon lifecycle wrapper (start/stop/status/logs) with supervisor dependency clarity
- [x] PMA engine routing (`PMA_DB_ENGINE`) native UX hardening

## Test Checklist

- [x] Native adapter contract smoke (new phase11 test pack)
- [x] Native core services parity smoke (phase11 core set)
- [x] Native php default/custom version matrix smoke
- [x] Services php alias target regression (`php84`/`php-fpm-8.4` -> php@version)
- [x] Host php version shim regression (`php8.4` / `php-fpm-8.4` executable wrappers)
- [x] Mode switch safety regression (laradock-bridge -> native auto-down guard)
- [x] Site + php version routing regression (native)
- [x] Horizon/supervisor dependency + lifecycle regression
- [x] DB + phpmyadmin operational path regression

## Documentation Checklist

- [x] `docs/contracts/cli-output-contract.md` native adapter contract extension
- [x] `docs/commands/services.md` native contract examples update
- [x] `docs/commands/site.md` native php/runtime parity update
- [x] `docs/commands/global.md` env autoload/bootstrap behavior update
- [x] `docs/operations/laravel-project-lifecycle.md` native-first adapter workflow update
- [x] Decision log update

## Gate Checklist (Mandatory)

- [x] Feature scope complete
- [x] Tests pass
- [x] Decision log updated
- [x] Next-phase risks written
- [x] Herd parity/beyond impact reviewed

## Notes

- Date: 2026-04-03
- Owner:
- Related PR/Commit:
- Progress:
  - `tests/phase11_native_adapter_contract_smoke.sh` added.
  - `tests/phase11_native_core_services_parity_smoke.sh` added and passed.
  - `tests/phase11_native_php_matrix_smoke.sh` added and passed.
  - `tests/phase11_mode_switch_laradock_down_smoke.sh` added and passed.
  - `php` command family activated (`list|install|use|alias list|alias set|alias default`).
  - Native PHP default/custom version configuration is persisted to the state file (`php.env`).
  - `env` command family added (`env where|init`) and global native env path management clarified.
  - Built-in native core env template added (`templates/native-core.env.example`).
  - With `mode use ... --down-running`, running compose services can be controlled `down` when switching from laradock-bridge to native.
  - Native/global env model active: default env `~/.config/plume/.env`, with automatic bootstrap support.
  - PHP target alias resolve expanded in the services contract:
    - `services up php84`, `services status php-fpm-8.4`, `services health php82`, `services logs php84`
    - all run via the canonical `php` service + target PHP version resolve.
  - New regression test added and passed:
    - `tests/phase11_services_php_alias_target_smoke.sh`
  - `plume_load_env` updated to preserve external env precedence:
    - `PLUME_*`/`PMA_*` values provided on the command line are not overwritten by global env.
  - Host php shim commands added:
    - `php shim install|env|list|remove`
    - executable shim files such as `php8.4` and `php-fpm-8.4` can be produced and added to PATH.
  - Shell bootstrap command added:
    - `init shell [--shell=zsh|bash] [--rc=...] [--force]`
    - writes the plume shim activation block to the rc file idempotently.
  - `php shim env` expanded:
    - exports shell aliases for all installed PHP versions other than default (`php81`, `phpfpm81`).
  - Doctor command expanded:
    - `doctor php [--strict]` reports cli/fpm binary availability for the configured PHP matrix.
    - in `--strict` mode, missing binaries yield `exit 2`.
  - Native `services install php` wired to real host binary provisioning:
    - install driver: `brew|apt` (dnf currently manual guidance)
    - after install: cli/fpm binary verify + php matrix state auto-register.
  - Native `services up php` auto-provision behavior added:
    - if the target version is not ready on the matrix/binary side, install+verify+register runs automatically.
  - PHP extension matrix added:
    - `PLUME_PHP_EXTENSIONS_GLOBAL` + `PLUME_PHP_EXTENSIONS_<major><minor>`
    - `php ext sync <version|all>` and `php ext doctor --strict`
    - extension auto-sync during `services up php` (`PLUME_PHP_EXTENSIONS_AUTO_SYNC=true`)
  - Doctor expansion:
    - `doctor php-ext --strict`
  - New tests added and passed:
    - `tests/phase11_php_shim_smoke.sh`
    - `tests/phase11_init_shell_smoke.sh`
    - `tests/phase11_php_shell_alias_export_smoke.sh`
    - `tests/phase11_doctor_php_smoke.sh`
    - `tests/phase11_doctor_web_smoke.sh`
    - `tests/phase11_services_web_sync_config_smoke.sh`
    - `tests/phase11_services_install_php_native_smoke.sh`
    - `tests/phase11_services_up_php_native_autoprovision_smoke.sh`
    - `tests/phase11_php_ext_sync_smoke.sh`
    - `tests/phase11_doctor_php_ext_smoke.sh`
    - `tests/phase11_services_up_php_ext_autosync_smoke.sh`
    - `tests/phase11_site_reload_validate_smoke.sh`
    - `tests/phase11_site_nginx_strict_publish_smoke.sh`
    - `tests/phase11_site_nginx_strict_missing_include_smoke.sh`
    - `tests/phase11_site_php_upstream_override_smoke.sh`
    - `tests/phase11_site_nginx_strict_no_double_reload_smoke.sh`
    - `tests/phase11_site_nginx_php_front_controller_smoke.sh`
    - `tests/phase11_site_apache2_caddy_strict_publish_smoke.sh`
    - `tests/phase11_php_ext_resolve_contract_smoke.sh`
    - `tests/phase11_php_ext_toggle_disable_precedence_smoke.sh`
    - `tests/phase11_site_check_strict_visibility_smoke.sh`
  - Core parity priority locked to a 6-service set:
    - `php(fpm)`, `nginx/caddy/apache2`, `mariadb/mysql`, `phpmyadmin`, `laravel-horizon`, `redis`
  - Native alias contract regression locked:
    - `php-fpm -> php`
    - `workspace -> composer`
    - `laravel-horizon -> horizon` (with supervisor guard)
  - Web server publish reliability strengthened:
    - Config test step added to the native `site publish --reload` flow (`PLUME_SITE_RELOAD_VALIDATE=true` default).
    - On invalid config, reload is skipped; if `PLUME_SITE_RELOAD_REQUIRED=true`, publish returns fail-fast.
    - Native nginx strict pipeline added (`PLUME_SITE_NGINX_STRICT=true`):
      - real include path sync (`PLUME_NGINX_INCLUDE_DIR` override or auto-detect),
      - lint (`nginx -t`) + reload requirement,
      - include rollback on failure.
      - Duplicate reload blocked when strict is used together with `site publish --reload`.
      - Strict pipeline also added for apache2 and caddy besides nginx (include sync + lint + reload + rollback).
  - Site-based PHP upstream override added:
    - `site add/update --php-upstream=<host:port|unix:/sock>`
    - `php_upstream` is stored in the site record; used with priority over the resolver during snippet render.
    - `site check` output shows `php_upstream` and `php_upstream_resolved` fields.
    - Strict publish visibility added to `site check` output:
      - `mode`, `strict_enabled`, `strict_include_dir`, `strict_include_target`
  - PHP extension contract moved to a hybrid model:
    - preset (`PLUME_PHP_EXT_PRESET`, `PLUME_PHP_EXT_PRESET_<ver>`)
    - toggle (`PLUME_PHP_EXT_ENABLE_*`, `PLUME_PHP_EXT_DISABLE_*`)
    - matrix (`PLUME_PHP_EXTENSIONS_GLOBAL`, `PLUME_PHP_EXTENSIONS_<ver>`)
    - resolve command: `php ext resolve <version|all>`
  - Native service contract surface completed:
    - service group behaviors: `@core`, `@web`, `@db`, `@queue`
    - site runtime resolve + `php_upstream` contract
    - `horizon` / `supervisor` dependency guard and lifecycle wrapper
    - `PMA_DB_ENGINE`-based `phpmyadmin` engine routing
  - Native parity regression pack completed:
    - `tests/phase11_native_core_services_parity_smoke.sh`
    - `tests/phase11_native_adapter_contract_smoke.sh`
- Open risks:
  - Edge-case risk while normalizing real OS service manager differences (launchd/systemd) under a single semantic.
  - Process ownership/permission drift risk in Horizon/supervisor lifecycle.
  - Native vs laradock-bridge output contract differences can cause breakage in the adapter parse layer.
