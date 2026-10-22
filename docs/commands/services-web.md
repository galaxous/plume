# `services web` Commands

## Purpose

**Guarantee** the native nginx HTTP listen port (default **80**) on macOS Homebrew and Linux apt/dnf. Plume manages the main `nginx.conf` listen value, obtains admin approval for privileged ports, and aligns site vhost snippets. Users are not told to run `brew` / `systemctl` (D-151).

## Usage

```bash
# One command: main conf -> 80, elevated restart, republish all native nginx sites
plumectl services web ensure

# Preview
plumectl services web ensure --dry-run

# Main conf only (no site republish)
plumectl services web ensure --no-republish

# Lower level (prefer ensure)
plumectl services web sync-config --reload
plumectl services web port 80 --reload
```

Site publish and `services up|restart web` also auto-ensure (`PLUME_NATIVE_NGINX_ENSURE_ON_PUBLISH` / `ENSURE_ON_WEB_UP`, default true).

## Parameters

### `ensure`

- `--port=<n>`: target HTTP port (default `PLUME_NATIVE_NGINX_HTTP_PORT`, default `80`)
- `--dry-run`: plan
- `--no-republish`: do not rewrite site confs

### `sync-config` / `port`

- `--port=<n>` / positional port
- `--dry-run`, `--reload`

## Environment variables

| Variable | Default | Meaning |
|----------|---------|---------|
| `PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG` | `true` | Manage main conf listen |
| `PLUME_NATIVE_NGINX_HTTP_PORT` | `80` | Target portless `http://site.test` |
| `PLUME_NATIVE_NGINX_ENSURE_ON_PUBLISH` | `true` | Ensure before `site publish` |
| `PLUME_NATIVE_NGINX_ENSURE_ON_WEB_UP` | `true` | Ensure before `services up/restart web` |
| `PLUME_NATIVE_NGINX_MAIN_CONF` | auto | Override path |
| `PLUME_NATIVE_HOMEBREW_HTTP_PORT` | unset | Legacy: force 8080 snippet (does not by-pass ensure; when manage is on, desired port wins — for 8080 set manage=false or HTTP_PORT=8080) |

## Output / Exit code

- `0`: on target port or ensure complete
- `2`: conf missing, `nginx -t` fail, admin denied / bind fail

## Examples

```bash
# ~/.config/plume/.env (or defaults)
PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=true
PLUME_NATIVE_NGINX_HTTP_PORT=80

plumectl services web ensure
# -> http://myapp.test  (no port)
```

Stay on 8080:

```bash
PLUME_NATIVE_NGINX_HTTP_PORT=8080
plumectl services web ensure --port=8080
```

## Error scenarios

- Port **80/443**: interactive terminal asks for sudo (via `/dev/tty` in IDE shells — D-159); if denied, ensure fails — rerun `plumectl services web ensure`.
- Listen already on target port: privileged reload soft-fails with a WARN; `site publish` still proceeds (reload happens after the snippet write).
- Root-owned conf/pid: elevated `nginx -t` / restart.
- Orphan duplicate `server_name` WARN: does not break publish; conf cleanup is separate.
- CI / `PLUME_NONINTERACTIVE=1`: passwordless `sudo -n` only (D-158); never an interactive Password prompt.

## Related

- `doctor web` / `doctor web fix-ports`
- `site publish <id> --reload`
- D-151, D-109
