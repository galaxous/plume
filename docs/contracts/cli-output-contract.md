# CLI Output Contract (Adapter Readiness)

This document defines CLI parse rules for a future `plume-adapter` integration.

## General Rules

- Primary command outputs go to `stdout` (site id, tables, JSON, key=value)
- Progress / log lines go to `stderr`: `[INFO]`, `[WARN]`, `[ERROR]` (D-157 — so parsed stdout such as `site add` is not polluted)
- Exit-code scheme:
  - `0`: success
  - `1`: runtime/internal error
  - `2`: validation/prereq/user-correctable error

## JSON Mode

The global `--json` flag enables it.

JSON-supported commands (minimum):

- `services supported`
- `services status`
- `prereq check`
- `site list`
- `site modes`
- `site check`

`site check --json` `data` fields (additional fields, backward compatible):

- `effective_http_port`, `url_http`, `url_https` (if cert exists), `access_hint`, `tcc_risk` (boolean; macOS Desktop/Documents/Downloads path)
- If `access_hint` is non-empty, the same text also appears in the `warnings` array
- If `tcc_risk` is true, the TCC text also appears in the `warnings` array

- `status`
- `health`
- `monitor summary`

JSON base schema:

```json
{
  "ok": true,
  "command": "services supported",
  "data": {},
  "warnings": [],
  "errors": []
}
```

Error schema:

```json
{
  "ok": false,
  "command": "prereq check",
  "errors": [
    {
      "code": "MISSING_DEPENDENCY",
      "message": "bash command not found",
      "hint": "Install bash and retry"
    }
  ]
}
```

`services supported --json` output schema:

```json
{
  "ok": true,
  "command": "services supported",
  "data": {
    "mode": "native",
    "services": [
      { "name": "php", "enabled": true },
      { "name": "redis", "enabled": false }
    ]
  },
  "warnings": [],
  "errors": []
}
```

`services status --json` output schema:

```json
{
  "ok": true,
  "command": "services status",
  "data": {
    "mode": "native",
    "services": [
      {
        "name": "php",
        "version": "8.4",
        "enabled": true,
        "running": true,
        "health": "healthy",
        "port": "9000",
        "desired": false,
        "resolved": false,
        "require_supervisor": false
      }
    ]
  },
  "warnings": [],
  "errors": []
}
```

## Native Adapter Contract Fields

- `enabled`: intent to run within the mode
- `running`: runtime state
- `health`: `healthy|stopped|disabled|unknown`
- `port`: active host port or `-`
- `desired`: desired service set for `laradock-bridge` only
- `resolved`: dependency-graph-expanded set for `laradock-bridge` only
- `require_supervisor`: visibility of supervisor dependency for horizon

In native mode `status` output format:

- the `web` line is written as `nginx|apache2|caddy` according to the active driver
- the `php-fpm` alias is normalized to the `php` line
- the `workspace` alias is normalized to the `composer` line
- the `laravel-horizon` alias is normalized to the `horizon` line

## Contract Change Rule

- When a breaking contract change is made:
  - This file is updated
  - A new decision is added to the Decision log
  - A migration note is written

## Text Table Stabilization (Phase-10 Baseline)

On parseable text tables outside `--json`:

- Header names must not be changed.
- Column order must be preserved.
- Empty values must be written as `-`.

This rule is mandatory for these commands:

- `services status`
- `status`
- `health`
- `site list`
- `monitor summary`

`site list` column order:

- `ID`
- `SERVER`
- `PHP`
- `PORT`
- `HTTPS`
- `CERT`
- `STATUS`
- `DOMAINS`
- `PATH`

The `PATH` column is always the last column; alignment is preserved even for large path values.

`site modes` text output schema:

- `ID`
- `MODE`
- `SERVER`
- `PHP`
- `STATUS`
- `PATH`

## Error Envelope

Validation errors return exit code `2` and text output in this pattern:

```text
[ERROR] <message>
```

Runtime/internal errors return exit code `1` and use the same prefix:

```text
[ERROR] <message>
```

Optional guidance lines:

```text
[INFO] next: <command>
```

## deploy apply (text)

`deploy apply` successful output template:

```text
MODE              <mode>
DRY_RUN           false|true
STEP               STATUS
------------------ ------
1.pre-deploy-backup ok|skipped
2.doctor-check     ok|skipped
3.services-update  ok|skipped (no root)|skipped
4.monitor-summary  ok
OVERALL            OK
```

In dry-run mode the line `OVERALL OK (dry-run)` is returned.

## project config show (text)

`project config show --path=...` output is `key=value` lines (stdout); `--json` is not supported and it is not in the `adapter.json_critical_commands` list (Phase 16 MVP).

Example:

```text
manifest=/abs/project/plume.yml
mode=native
php_version=8.3
```

## services url / credentials (text)

Native-only key=value stdout; `--json` is not supported.

```text
url=http://127.0.0.1:8083
host=127.0.0.1
port=5432
```

See [docs/commands/services-url.md](../commands/services-url.md).

## services use (text)

Native-only key=value stdout; `--json` is not supported.

```text
engine=mariadb
enabled_mariadb=true
enabled_mysql=false
enabled_postgres=false
enabled_phpmyadmin=true
enabled_pgadmin=false
```

See [docs/commands/services-use.md](../commands/services-use.md).
