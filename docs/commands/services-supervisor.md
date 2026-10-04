# `services supervisor`

## Purpose

System-primary native supervisor (brew services / systemd): package upgrade + config migration and template-based program conf add (D-149).

## Usage

```bash
./plume.sh doctor supervisor
./plume.sh services supervisor upgrade --force --yes
./plume.sh services supervisor upgrade --force --yes --dry-run
./plume.sh services supervisor program add
./plume.sh services supervisor program add --template=horizon --non-interactive
./plume.sh services up supervisor
./plume.sh services up horizon
./plume.sh services up horizon --site=<site-id>
```

Preferred path for Horizon: `site update <id> --horizon` + `services up horizon` (D-150, per-site `plume-horizon-<site-id>`). Manual `program add --template=horizon` is for custom workers.

Diagnose and logs: `plumectl doctor supervisor`, `plumectl services logs horizon` — you do not need to run `supervisorctl` (D-152).

## Parameters

### `upgrade`

- `--force` (required): package upgrade + legacy Plume supervisord migration
- `--yes` (required): confirm critical operation
- `--dry-run`: print plan, do not apply

### `program add`

- `--template=generic|horizon`
- `--name=plume-worker` — program name (`[program:name]`)
- `--non-interactive`: use template defaults (smoke/CI)

In interactive mode, each template placeholder is prompted; confirmation is required after preview.

Program conf target by OS:

- macOS Homebrew: `$(brew --prefix)/etc/supervisor.d/plume-*.ini` (Homebrew include `*.ini`; D-153)
- Debian/Ubuntu: `/etc/supervisor/conf.d/` (sudo may be required)
- RHEL/Fedora: `/etc/supervisord.d/` or `/etc/supervisor/conf.d/`

Plume reads the drop-in directory/extension from `supervisord.conf` `[include] files=`; a wrong `opt/supervisor/etc` cache is ignored.
Registry: `$(plume_state_dir)/native/supervisor/programs-registry.env`

## Output / exit-code

- `0`: success
- `2`: missing `--force`/`--yes`, write error, supervisor down

## Examples

```bash
# Legacy D-147 -> system-primary migration
./plume.sh services supervisor upgrade --force --yes

# Horizon worker (tunnelion)
PLUME_HORIZON_PATH=/path/to/laravel
./plume.sh services supervisor program add --template=horizon --non-interactive

# Generic queue worker
./plume.sh services supervisor program add --template=generic
```

## Error scenarios

- `upgrade requires --force` — use `--force --yes` for intentional migration
- `cannot write supervisor program conf` — sudo on Linux or a writable conf.d
- No artisan for Horizon — `PLUME_HORIZON_PATH` or site record

Related: [doctor-supervisor.md](./doctor-supervisor.md), [services-horizon.md](./services-horizon.md).
