# Laravel Project Lifecycle Runbook

This runbook is the reference for managing a Laravel project with Plume as easily as possible in local/prod environments.

## 1. Bootstrap

1. `plumectl project init --path=/abs/project`
2. As needed: `plumectl project init --path=/abs/project --migrate --seed --npm-install --npm-build`
3. Composer install
4. Prepare `.env`
5. `php artisan key:generate`
6. `php artisan storage:link`
7. Optional migrate/seed/npm steps

## 2. Site Onboarding

1. `plumectl site add` (interactive) or non-interactive flags
2. Verify registration with `plumectl site list`
3. Validate with `plumectl site check <site-id>`
4. Use `site add --publish` and, if needed, `site publish` for webserver snippet, hosts sync, and nginx reload flows.
5. Per-site PHP runtime selection is clarified with `--php-upstream=<host:port|unix:/sock>`.
6. Domain plan and TLS strategy are expanded under phase5+.

## 3. Runtime Services

1. Supported service status is shown with `plumectl services status`.
2. In native mode, `@core`, `@web`, `@db`, `@queue` service groups are used.
3. `plumectl services up php --version=<alias|version>` quickly runs the target PHP matrix and extension contract.
4. `plumectl services up laravel-horizon` enforces the supervisor dependency in native mode.
5. `plumectl services up phpmyadmin` applies engine routing via `PMA_DB_ENGINE` in native mode.
6. Queue/Horizon/Scheduler activation was designed as phase 6+ scope, but the native parity flow is now preserved at the adapter level.
7. Basic validation with `plumectl status`/`site check`.

## 4. Deploy (Production)

1. Preflight (`prereq check`, `doctor check --deep`)
2. Step list with `plumectl deploy plan --mode=...`
3. `plumectl --yes deploy apply --mode=...` (backup + reconcile + monitor strict)
   - In CI or constrained environments: `--skip-backup`, `--skip-reconcile`, `--skip-health` combinations
4. Migration gate (`php artisan migrate --force` inside the project)
5. Queue/Horizon recycle (`services up horizon` / supervisor)
6. Health gate (`monitor summary --strict`, site `/up`)
7. On problems, `deploy rollback latest` and if needed `deploy failback`
6. On failure, rollback (phase 9+)

## 5. Operate

1. `plumectl status`
2. Domain/site status with `plumectl status`
3. `plumectl logs <service>` (phase 9+ scope)
4. `plumectl backup create` (optional config+db)

## 6. Incident Recovery

1. Identify the problematic release
2. `plumectl rollback latest`
3. Health check
4. Incident note and decision log

## Native-First Adapter Note

- Native mode is designed to use the same command family as laradock-bridge.
- Web server selection is resolved among `nginx|apache2|caddy` according to the active driver.
- PHP upstream can be pinned per site; this is the most critical contract for projects that use a multi-PHP matrix.
- DB and queue services are tracked with the same nomenclature independent of mode, but runtime behavior uses native service management.
