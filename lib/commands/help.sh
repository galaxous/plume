#!/usr/bin/env bash
set -euo pipefail

cmd_help() {
  cat <<'EOF'
Plume CLI (plumectl)

USAGE:
  plumectl [global options] <command> [subcommand] [options]

GLOBAL OPTIONS:
  -h, --help                Show help
  -v, --version             Show version
  --json                    JSON output for supported commands
  --yes                     Confirm critical operations (required for guarded commands)
  --quiet                   Suppress info logs
  --env-file <path>         Load env file from custom path

COMMANDS:
  help                       Show help
  version                    Show version
  context                    Show global context (mode/path/lock) in one table
  env where|init|set          Show/init/set global plume env (~/.config/plume/.env)
  init shell                 Configure shell rc to auto-enable plume php shims
  init host [--force] [--json] [--apply]  Detect host profile; bootstrap services.yml; --apply runs manifest provision
  init onboarding [--fix] [--open-settings]  First-run checklist; --fix starts brew nginx/php
  init permissions [--open] [--reveal] [--interactive]  macOS FDA helper + optional TTY menu
  mode current|context|use <mode> [--force] [--down-running]
                             Manage active mode (locked context requires --force)
  php list|install|use|alias|ext|shim
                             Manage native PHP versions, aliases, extensions and host CLI shims
  mode path set|get|clear|list [mode] [path] [--force]
                             Manage active/global workspace path (mode optional; defaults to active mode)
  prereq check               Run prerequisite checks (profile-aware)
  prereq explain             List prereq profiles and reasons
  services supported         Show supported services
  services status            Show enabled/running/health/port/version
  services install <target>  Run install hook (target: service|all)
  services up <target>       Run start hook (target: service|all-enabled)
  services down <target>     Run stop hook (target: service|all-enabled)
  services restart <target>  Stop then start (apply .env changes; native webui/npm)
  services env show|set      Stack connection env (redis, mongodb, rabbitmq, webui)
  services health [target]   Show health state (target: service|all)
  services logs <target>     Show service logs (--tail=30)
  services exec <target>     Open shell/command in container (docker-lite/laradock-bridge only)
  services containers        List compose containers (docker-lite/laradock-bridge only)
  services laradock <op>     Laradock bridge bootstrap/sync/check (op: init|sync|check)
  services workspace <op>    Docker-lite workspace (op: init|reinit|apply|up|refresh|rebuild|down|status, use --path=)
  sync state                 Reconcile live runtime state into files + SQLite
  sync cron <op>             Install/remove/status hourly sync cron (op: install|remove|status|run)
  schedule status [--mode=...] [--path=...]
                             Laravel scheduler hint + user crontab detection (MVP)
  schedule list [--path=...] Run php artisan schedule:list in project dir
  schedule run-once [--path=...] [--dry-run]
                             Run php artisan schedule:run once (--no-interaction)
  schedule cron-install [--path=...] [--dry-run] [--remove]
                             Add or remove user crontab line for schedule:run (marker # plume-laravel-schedule-cron)
  queue status [--mode=...] [--path=...]
                             Queue/Horizon/supervisor status from env + services runtime
  queue list [--mode=...] [--path=...]
                             Run php artisan queue:failed (Horizon: see queue.md)
  services manifest show       Print effective native stack from services.yml + env
  services provision --from-manifest [--dry-run]
  services url <service>           Native HTTP URL (phpmyadmin, mongo_webui, redis_webui, …)
  services credentials <service>     Native DB/broker credentials (postgres, mariadb, redis, …)
  services redis sync-config [--reload|--dry-run]  Apply PLUME_REDIS_* to native redis.conf
  site add --path --domain --server=[nginx|apache2|caddy] [--php=8.1|8.2|8.3|8.4|default] [--publish] [--server-config=] [--dry-run]
                             Register and onboard site for local serving
  site update <site-id> --server=[nginx|apache2|caddy] [--php=8.1|8.2|8.3|8.4|default] [--port=80] [--publish] [--server-config=] [--dry-run]
                             Update an existing site registration
  site publish <site-id> [--reload] [--dry-run]
                             Rebuild and write local site snippet
  site list                  List registered sites
  site check <site-id>       Show site details
  site remove <site-id> [--dry-run]
                             Remove site from registry
  project init --path=...    Bootstrap Laravel project (.env/composer/artisan/npm)
  project config show --path=...  Read project plume.yml MVP fields (mode, php_version, type)
  project env sync-secrets --path=... [--keys=K1,K2] [--dry-run] [--create-env]
                             Sync plume secrets store into Laravel project .env
  deploy plan [--mode=...]
                             Print command-driven deploy/rollback plan
  deploy apply [--mode=...]
                             Reserved for phase9+ deploy execution pipeline
  deploy rollback <id|latest> [--mode=...] [--dry-run]
                             Restore selected backup and create failback point
  deploy failback [--mode=...] [--dry-run]
                             Restore last failback point created by rollback
  backup create [--mode=...] [--scope=all|config|db] [--name=...] [--output-dir=...]
                             Create backup archive (state config + optional sqlite db)
  backup list [--mode=...]
                             List backup archives under state backup directory
  backup show <id|file> [--mode=...]
                             Print backup metadata
  backup restore <id|file> [--mode=...] [--dry-run]
                             Restore backup archive (requires --yes unless dry-run)
  security check [--mode=...] [--skip-prereq]
                             OS/firewall security preflight snapshot
  security secrets list|get|set|unset|generate ...
                             Local secret store baseline under state directory
  security cert issue --domains=d1,d2 [--days=30] [--name=id]
                             Issue local multi-domain self-signed certificate
  security cert list|show|renew ...
                             List/show/renew local certificate artifacts
  status [service|@group] [--mode=...] [--running] [--watch[=2]]
                             Service status view (wrapper for services status)
  health [service|@group] [--mode=...] [--running] [--watch[=2]]
                             Service health view (wrapper for services health)
  logs <service|all|@group> [--mode=...] [--tail=30] [--follow] [--running]
                             Service logs view (wrapper for services logs)
  monitor summary [--mode=...] [--strict]
                             Compact ops summary (running status + health)
  monitor watch [--mode=...] [--interval=2]
                             Live running status watch loop
  monitor events [--mode=...] [--limit=30]
                             Show recent runtime events from state DB
  monitor runbook [--mode=...] [--scenario=incident|recovery|ports-conflict]
                             Print command-driven incident/recovery runbook
  doctor check [--mode=...] [--deep]
                             Run environment and runtime diagnostics
  doctor services [--mode=...]
                             Alias to services status for diagnostics
  doctor ports [--mode=...]
                             Show running services with exposed ports
  doctor php [--strict]
                             Check php/php-fpm binaries for all configured php versions
  doctor php-ext [--strict]
                             Check configured php extensions per version matrix
  doctor web [--mode=...] [--strict]
                             Native web server diagnostics (driver, listeners, strict includes)
  doctor host [--force]      Idempotent host profile detection (same as init host)
  doctor onboarding [--fix] [--open-settings]  First-run checklist (alias to init onboarding)

CRITICAL GUARDS:
  - mode use <mode> --force               (requires --yes)
  - mode path set|clear ... --force       (requires --yes)
  - services workspace reinit --mode=docker-lite (requires --yes)
  - services update                        (requires --yes + root)
  - backup restore                         (requires --yes unless --dry-run)
  - deploy rollback                        (requires --yes unless --dry-run)
  - deploy failback                        (requires --yes unless --dry-run)
EOF
}

cmd_version() {
  echo "plumectl 0.2.0-phase2"
}
