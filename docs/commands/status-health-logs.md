# `status`, `health`, `logs`, `doctor`, `monitor`

## Purpose

Monitor system health, logs, and runtime status.

## Usage

```bash
plumectl status --mode=native
plumectl health --mode=laradock-bridge --running
plumectl logs nginx --mode=laradock-bridge --tail=100 --follow
plumectl doctor check
plumectl doctor check --deep
plumectl doctor web --mode=native
plumectl doctor web --mode=native --strict
plumectl doctor web fix-ports --reload
plumectl doctor supervisor [--strict]
plumectl doctor host
plumectl doctor onboarding [--fix] [--open-settings]
plumectl doctor services
plumectl doctor ports
plumectl monitor summary --mode=native
plumectl monitor summary --mode=native --strict
plumectl monitor watch --mode=laradock-bridge --interval=3
plumectl monitor events --mode=native --limit=50
plumectl monitor runbook --mode=laradock-bridge --scenario=incident
```

## Parameters

- `status|health`: `--mode=...`, `--running`, `--watch[=N]`
- `logs`: `--mode=...`, `--tail=N`, `--follow`, `--running`
- `monitor watch`: `--interval=N`
- `monitor summary`: `--strict` (exit code `2` if a critical issue exists)
- `monitor events`: `--limit=N`
- `monitor runbook`: `--scenario=incident|recovery|ports-conflict`
- `--mode=<native|docker-lite|laradock-bridge>` (`doctor` subcommands)
- `--deep` (`doctor check`)
- `--strict` (`doctor web`, `doctor php`, `doctor php-ext`, `monitor summary`)

### `doctor web` (native focus)

Diagnostic lines for the web server (default `PLUME_WEB_SERVER_DRIVER`):

| CHECK | Meaning |
|-------|---------|
| `web-enabled` | Whether `PLUME_WEB_SERVER_ENABLED` is on |
| `native-binary` | nginx/apache/caddy binary path (native) |
| `init-system` | Homebrew `brew services` or systemd `active`/`started` |
| `listener-effective` | Whether LISTEN exists on registry HTTP port + `plume_sites_effective_http_port` (e.g. 80→8080) |
| `listener-80` | Whether port 80 is listening (WARN when Homebrew defaults to 8080; target 80 via `services web sync-config`) |
| `listener-https` | Listener on `PLUME_WEB_HTTPS_PORT` (443) |
| `strict-includes` | With `PLUME_SITE_NGINX_STRICT_ON_RELOAD`, whether cache snippet is in target include and matches |
| `sites-port80` | Count of registry sites with `port: 80` vs real port 80 listener |
| `macos-site-tcc` | (macOS) Whether site path is under `Desktop`/`Documents`/`Downloads` — WARN + `init permissions --interactive` hint |

`OVERALL FAIL` + `--strict` → exit code `2` (FAIL on critical lines).

## Output / Exit Codes

- `0`: healthy/report succeeded
- `1`: general error
- `2`: critical issue detected

## Examples

```bash
plumectl status --mode=native --watch=2
plumectl doctor check --mode=native --deep
plumectl doctor web --mode=native --strict
plumectl doctor services --mode=laradock-bridge
plumectl doctor ports --mode=docker-lite
plumectl monitor events --mode=laradock-bridge --limit=20
plumectl monitor runbook --mode=native --scenario=recovery
```

## Error scenarios

- Log source unreadable
- Health-check commands missing
- State/registry corrupted
- `sqlite3` missing for `monitor events`
