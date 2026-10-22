# `init host` Command

## Purpose

Detect machine identity on first install (and when needed) and write it to `~/.config/plume/host.env`. Adapter and doctor commands can parse this file.

## Usage

```bash
plumectl init host
plumectl init host --force
plumectl init host --json
plumectl init host --apply
plumectl doctor host
plumectl doctor host --force
```

If missing, `templates/services.yml.example` → `~/.config/plume/services.yml` is copied (existing file is kept). See [services-manifest.md](../operations/services-manifest.md).

## Parameters

- `--force`: re-detect and overwrite the existing profile
- `--json`: emit output as a single-line JSON (file content fields)
- `--apply`: native host install from the manifest (same as `services provision --from-manifest`)

## File format

Path: `~/.config/plume/host.env` (override: `PLUME_HOST_PROFILE_FILE`)

Fields (key=value):

| Field | Description |
|-------|-------------|
| `os` | `macos`, `linux`, `windows`, `unknown` |
| `os_version` | macOS productVersion or linux VERSION_ID |
| `arch` | `uname -m` |
| `package_manager` | `brew`, `apt`, `dnf`, `manual`, `missing` |
| `web_driver_hint` | Active `PLUME_WEB_SERVER_DRIVER` (default nginx) |
| `nginx_http_port_detected` | Main nginx.conf listen port (empty = not found) |
| `homebrew_nginx` | `true` / `false` |
| `state_dir` | Current `PLUME_STATE_DIR` value |
| `detected_at` | UTC ISO8601 |
| `native_support_note` | Windows only: limited native mode note |

## Output / Exit code

- `0`: success or profile already exists (without `--force`)
- `2`: write/option error

## Examples

```bash
plumectl init host
grep nginx_http_port_detected ~/.config/plume/host.env
```

## Automatic bootstrap

With `PLUME_AUTO_HOST_BOOTSTRAP=true` (default), if the profile is missing, the first `plume.sh`/`plumectl` call silently runs `init host`. To disable:

```bash
export PLUME_AUTO_HOST_BOOTSTRAP=false
```

## Error scenarios

- `$HOME/.config/plume` not writable: exit 2
- Windows/Git Bash: `os=windows` and `native_support_note` are set; full native nginx is not installed

## Related

- `docs/operations/first-run-onboarding.md`
- `init onboarding`, `doctor web`, `services web sync-config`
