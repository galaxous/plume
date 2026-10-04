# `queue` Commands

## Purpose

Laravel queue operations: worker/Horizon status (`status`) and failed job list (`list` → `queue:failed`). On native, Horizon is the real worker (D-147): `services up horizon --mode=native` starts supervisor + `php artisan horizon`. `php_worker` remains registry-only.

## Usage

```bash
./plume.sh queue status
./plume.sh queue status --mode=native
./plume.sh queue status --path=/abs/laravel-app
./plume.sh --json queue status --mode=native

./plume.sh queue list --path=/abs/laravel-app
./plume.sh queue list --mode=native --path=/abs/laravel-app
```

## Parameters

- `status` (default subcommand): Queue/Horizon summary.
- `list`: Runs `php artisan queue:failed` in the project directory. If `PLUME_HORIZON_ENABLED=true`, extra INFO: `horizon:status` and suggestion to run `./plume.sh services status horizon`.
- `--mode=native|docker-lite|laradock-bridge`: Service runtime source (for `status` and Horizon hint).
- `--path=/abs/project`: Force Laravel project root (resolution same as `schedule status`).
- Global `--json`: JSON output for `status` only.

## Output / Exit Codes

- `0`: Success.
- `1`: Artisan `queue:failed` failed (Laravel exit code is forwarded).
- `2`: Invalid argument, project path unresolved, `artisan` missing, or `php` not found.

Text `status` output: `QUEUE_CONNECTION`, `HORIZON` / `SUPERVISOR` / `PHP_WORKER` lines. In native mode, if Horizon is enabled but not running, hint: `./plume.sh services up horizon --mode=native`.

For detailed Horizon status, use `php artisan horizon:status` directly (or `services status horizon`) instead of plume `queue list`.

## Examples

```bash
# tunnelion + Horizon env
PLUME_HORIZON_ENABLED=true ./plume.sh queue status --mode=native --path=/Users/me/Desktop/Projects.nosync/tunnelion
./plume.sh queue list --path=/Users/me/Desktop/Projects.nosync/tunnelion

./plume.sh queue status --path=/var/www/myapp --mode=docker-lite
```

## Error scenarios

- Project path cannot be resolved.
- If the service is unsupported in the mode, `status` line shows `unsupported` health.
- Horizon supervisor requirement (`PLUME_HORIZON_REQUIRE_SUPERVISOR`) follows the same rules as `services up horizon`; these commands are status / Artisan wrappers only.
