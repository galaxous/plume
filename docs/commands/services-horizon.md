# `services` horizon / supervisor (native)

## Purpose

Native queue worker similar to the Laradock `laravel-horizon` container: Supervisor process manager + `php artisan horizon`. Redis is a separate service (`services up redis`).

**Multiple projects:** A separate supervisor program per site record (`plume-horizon-<site-id>`, D-150). Global `PLUME_HORIZON_PATH` is legacy fallback only.

**Operations:** Only `plumectl` / `plumectl` — you do not need to run `supervisorctl` or `brew services` (D-152).

## Usage

```bash
plumectl site update site-xxx --horizon
plumectl services up redis --mode=native
plumectl services up horizon --mode=native
plumectl services up horizon --site=site-xxx --mode=native
plumectl services down horizon --site=site-xxx --mode=native
plumectl services restart horizon --site=site-xxx
plumectl services status horizon
plumectl services logs horizon --tail=50
plumectl services logs horizon --site=site-xxx --tail=50
plumectl doctor supervisor --strict
plumectl services supervisor upgrade --force --yes
plumectl services status @queue --mode=native
```

## Parameters

- `--mode=native`
- `--site=<site-id>`: write/start/stop/log the horizon program for that site only
- Site record `horizon: true`: `site add|update --horizon` / `--no-horizon`
- `PLUME_HORIZON_PATH` (legacy): single `plume-horizon` program when no horizon-enabled site exists
- `PLUME_HORIZON_REQUIRE_SUPERVISOR` (default `true`): `up horizon` requires supervisor enabled
- PHP: site `php_version` or `PLUME_PHP_DEFAULT_VERSION`

Plume installs the Homebrew/apt `supervisor` package; the **system** supervisor is used. Program conf is written to the OS drop-in directory (D-149). On macOS, Homebrew include: `$(brew --prefix)/etc/supervisor.d/*.ini` (D-153). See [services-supervisor.md](./services-supervisor.md).

## Output / exit-code

- `0`: install/start succeeded; status `health=healthy` (all target programs RUNNING)
- `2`: supervisor disabled, target site missing, artisan not found, or health fail

On health fail, Plume prints automatic diagnose output: program status, worker log tail, Redis/.env hints, and next `plumectl` steps.

## Examples

```bash
# tunnelion + another project
plumectl site add --path=/path/tunnelion --domain=tunnelion.test --horizon --publish
plumectl site add --path=/path/other --domain=other.test --horizon --publish
plumectl services up redis --mode=native
plumectl services up horizon --mode=native

# single project
plumectl services up horizon --site=site-1775207595-23239

# stopped / FATAL
plumectl doctor supervisor
plumectl services logs horizon --site=site-1775207595-23239 --tail=50
plumectl services restart horizon --site=site-1775207595-23239
```

Laravel `.env`: `QUEUE_CONNECTION=redis`, `REDIS_HOST=127.0.0.1` (if Redis has a password, `REDIS_PASSWORD` must match the supervisor worker).

## Error scenarios

- `horizon requires supervisor` — `SUPERVISOR_ENABLED=true` / `plumectl services up supervisor`
- `no horizon targets` — `--horizon` on at least one site, or legacy `PLUME_HORIZON_PATH`
- `site has no Laravel project with artisan` — valid site path + `artisan`
- health `stopped` — `plumectl services logs horizon` (Redis auth, missing Horizon migrate, artisan error)
- `php_worker` remains registry-only on native; for `queue:work` use docker-lite or run manually
