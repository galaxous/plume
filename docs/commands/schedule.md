# `schedule` Commands

## Purpose

Laravel scheduler operations: status summary (`status`), registered task list (`list`), one-shot `schedule:run` (`run-once`), and user crontab line add/remove (`cron-install`).

## Usage

```bash
./plume.sh schedule status
./plume.sh schedule status --mode=native
./plume.sh schedule status --path=/abs/laravel-app
./plume.sh --json schedule status --path=/abs/laravel-app

./plume.sh schedule list --path=/abs/laravel-app
./plume.sh schedule run-once --path=/abs/laravel-app
./plume.sh schedule run-once --path=/abs/laravel-app --dry-run

./plume.sh schedule cron-install --path=/abs/laravel-app
./plume.sh schedule cron-install --path=/abs/laravel-app --dry-run
./plume.sh schedule cron-install --path=/abs/laravel-app --remove
```

## Parameters

- `status` (default subcommand): Scheduler status.
- `list`: Runs `php artisan schedule:list` in the project directory (Laravel 8+); output belongs to Artisan.
- `run-once`: Runs `php artisan schedule:run --no-interaction` once in the project directory.
- `cron-install`: Adds a single line to the user's crontab (not root), or removes it with `--remove`. Lines end with the `# plume-laravel-schedule-cron` marker.
- `--dry-run` (`run-once`, `cron-install`): Does not run the command/crontab write; prints the planned shell or crontab line.
- `--remove` (`cron-install`): Deletes plume scheduler lines containing the marker from crontab.
- `--mode=native|docker-lite|laradock-bridge`: Mode context for `status` (ignored by other subcommands).
- `--path=/abs/project`: Force Laravel project root; if omitted, tries registered site (CWD match), `artisan` in CWD, or active mode workspace path.
- Global `--json`: JSON output for `status` only (`ok`, `command`, `data`).
- Test/smoke: `PLUME_CRONTAB_FILE=/path/to/file` uses a file instead of real `crontab` (hermetic tests).

## Output / Exit Codes

- `0`: Success (`status`, `list`, `run-once`, `cron-install`, `--dry-run`, `--remove`, already installed idempotent).
- `1`: Artisan command failed (`list`, `run-once`; Laravel exit code is forwarded).
- `2`: Invalid argument, project path unresolved, `artisan` missing, `php` not found, root user, or `crontab` missing.

Text `status` output: `MODE`, `PROJECT_PATH`, `PROJECT_SOURCE`, `ARTISAN` (`present|missing`), `SCHEDULER_CRON` (`configured|maybe|not-configured|unknown`), `CRON_HINT`.

`cron-install` line (example): `* * * * * cd /abs/project && /path/to/php artisan schedule:run >> /dev/null 2>&1 # plume-laravel-schedule-cron` — PHP path is resolved from site version or `PLUME_PHP_BIN`.

`run-once`: If crontab is missing (`not-configured`), after a successful run INFO reminds about `cron-install` or `CRON_HINT`.

## Examples

```bash
# tunnelion (Desktop — site registered or --path)
./plume.sh schedule status --path=/Users/me/Desktop/Projects.nosync/tunnelion
./plume.sh schedule cron-install --path=/Users/me/Desktop/Projects.nosync/tunnelion --dry-run
./plume.sh schedule cron-install --path=/Users/me/Desktop/Projects.nosync/tunnelion
./plume.sh schedule list --path=/Users/me/Desktop/Projects.nosync/tunnelion
./plume.sh schedule run-once --path=/Users/me/Desktop/Projects.nosync/tunnelion --dry-run
./plume.sh schedule run-once --path=/Users/me/Desktop/Projects.nosync/tunnelion

cd ~/Desktop/Projects.nosync/tunnelion && ./plume.sh schedule list
./plume.sh schedule cron-install --path=/Users/me/Desktop/Projects.nosync/tunnelion --remove
```

## Error scenarios

- Project path not found (`--path` required, or site/CWD/mode path must be set).
- Without `crontab`, `status` shows `SCHEDULER_CRON=unknown`; `cron-install` exits `2`.
- When run as root, `cron-install` exits `2` (targets user crontab).
- Without `artisan`, `list` / `run-once` / `cron-install` exit `2`; `status` continues with WARN.
- On older Laravel versions that do not support `--no-interaction`, `run-once` returns exit `1` with an Artisan error.
- If the same marker already exists, `cron-install` does not add again (exit `0`, INFO).
