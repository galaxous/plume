# `doctor supervisor`

## Purpose

Diagnose native supervisor install, system unit (brew services / systemd), legacy Plume daemon leftovers, package upgrade need, and registered program confs (D-149).

## Usage

```bash
plumectl doctor supervisor
plumectl doctor supervisor --strict
```

## Parameters

- `--mode=native` (default: active mode)
- `--strict`: exit 2 on critical FAIL or upgrade WARN

Host info is read from `~/.config/plume/host.env` cache (`package_manager`, `supervisor_*`). If missing, `init host --force` is recommended.

## Output / exit-code

- `0`: OVERALL OK (WARN allowed)
- `2`: `--strict` and critical FAIL / upgrade required

Remediation line (when upgrade is needed):

```text
REMEDIATION  run: plumectl services supervisor upgrade --force --yes
```

## Examples

```bash
plumectl doctor supervisor --strict
plumectl init host --force
```

## Error scenarios

- `supervisord` / `supervisorctl` missing — `services install supervisor`
- Legacy Plume-owned supervisord — `services supervisor upgrade --force --yes`
- `horizon-program` WARN — `plumectl site update <id> --horizon` then `plumectl services up horizon`
- Per-site check: `horizon-program:<site-id>` (D-150)
- Program not RUNNING — `plumectl services logs horizon --site=<id>` and `plumectl services restart horizon --site=<id>` (D-152; supervisorctl not required)

Related: [services-supervisor.md](./services-supervisor.md), [services-horizon.md](./services-horizon.md).
