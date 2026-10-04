# `backup`

## Purpose

Archive and restore Plume state/config and SQLite state data.

## Usage

```bash
plumectl backup create --mode=native --scope=all
plumectl backup list --mode=native
plumectl backup show <backup-id>
plumectl backup restore <backup-id> --dry-run
plumectl --yes backup restore <backup-id>
```

## Parameters

- `create`
  - `--mode=<native|docker-lite|laradock-bridge>`
  - `--scope=all|config|db` (default: `all`)
  - `--name=<label>`
  - `--output-dir=<path>`
- `list`
  - `--mode=...`
- `show`
  - `<id|file>`
  - `--mode=...`
- `restore`
  - `<id|file>`
  - `--mode=...`
  - `--dry-run`

## Output / Exit Codes

- `0`: success
- `1`: general error
- `2`: invalid parameter/guard blocked

## Examples

```bash
plumectl backup create --scope=config --name=pre-upgrade
plumectl backup list
plumectl backup show backup-pre-upgrade-20260403-120000
plumectl backup restore backup-pre-upgrade-20260403-120000 --dry-run
plumectl --yes backup restore backup-pre-upgrade-20260403-120000
```

## Error scenarios

- Backup file not found
- Invalid `--scope`
- `--yes` not given for restore
