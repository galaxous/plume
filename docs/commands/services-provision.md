# services provision

## Purpose

Install and (when defined) start host packages from the `~/.config/plume/services.yml` manifest in native mode.

**Native auto-install:** web (nginx/apache2 driver), MariaDB/MySQL, **PostgreSQL**, Redis, **Memcached**, **MongoDB**, **RabbitMQ**, **phpMyAdmin**, **pgAdmin**, **mongo_webui**, **redis_webui**, **mailpit (macOS Homebrew)**, **supervisor + Horizon**; best-effort host PHP (brew/apt) for the manifest `php.versions` list.

**YAML/env toggle only (no native package):** php_worker, meilisearch, minio — `enabled: true` loads env; `health=registry` (D-146).

**Auto-provision (D-119):** `PLUME_NATIVE_SERVICE_AUTO_PROVISION=true` (default) — in native mode, `enabled=true` services try host install+start via `services up`. Escape: `--no-provision`.

## Usage

```bash
plumectl services provision --from-manifest [--dry-run]
```

Equivalent:

```bash
plumectl init host --apply
```

(`init host` also writes `host.env` and copies the manifest template if missing.)

## Parameters

| Option | Description |
|--------|-------------|
| `--from-manifest` | Required. Manifest path: `PLUME_SERVICES_MANIFEST_FILE` or `~/.config/plume/services.yml` |
| `--dry-run` | Does not install; `services manifest show` effective lines + info log |

## Output / exit code

- **0**: Success (or dry-run).
- **2**: Manifest missing, mode ≠ native, privilege/prompt cancelled, install error.

## Examples

```bash
# Plan
plumectl services provision --from-manifest --dry-run

# Real install (macOS: brew approval on TTY; PLUME_NONINTERACTIVE=1 in CI)
plumectl services provision --from-manifest
```

## Error scenarios

- Manifest missing → bootstrap with `init host`.
- With `database.engine: mysql`, the MariaDB formula is not installed; `PLUME_MYSQL_ENABLED=true` is set.
- `mailpit.enabled: true` on Linux native has no brew hook → warning; on macOS `brew install mailpit`. Alternative: docker-lite or manual install.
- User cancels at interactive prompt → exit 2.
- Windows native full stack is not supported (host profile limited note).

## Related docs

- [services-manifest.md](../operations/services-manifest.md)
