# `deploy`

## Purpose

Plan the deploy flow, run a controlled apply, and use rollback/failback commands when something goes wrong.

## Usage

```bash
plumectl deploy plan --mode=native
plumectl deploy apply --mode=native --dry-run
plumectl --yes deploy apply --mode=native --skip-backup --skip-reconcile
plumectl deploy rollback latest --mode=native --dry-run
plumectl --yes deploy rollback latest --mode=native
plumectl --yes deploy failback --mode=native
```

## Parameters

- `plan`
  - `--mode=<native|docker-lite|laradock-bridge>`
- `apply`
  - `--mode=...`
  - `--dry-run`
  - `--skip-backup`
  - `--skip-health`
  - `--skip-reconcile` (on macOS without root, `services update` can be skipped)
  - `--yes` (critical approval; required except dry-run)
- `rollback`
  - `<id|latest>`
  - `--mode=...`
  - `--dry-run`
- `failback`
  - `--mode=...`
  - `--dry-run`

## Output / Exit Codes

- `0`: success
- `1`: general error
- `2`: guard/parameter/backup missing, doctor/monitor gate fail

Apply steps (not dry-run):

1. Pre-deploy backup (`--scope=config`, `--name=pre-deploy`) — skipped with `--skip-backup`
2. `doctor check --deep` — skipped with `--skip-health`
3. `services update` — skipped with `--skip-reconcile`
4. `monitor summary --strict`

## Examples

```bash
plumectl deploy plan --mode=laradock-bridge
plumectl --yes deploy apply --mode=native
plumectl --yes deploy rollback latest --mode=laradock-bridge
plumectl --yes deploy failback --mode=laradock-bridge
```

## Error scenarios

- No backup for `latest`
- No failback marker
- rollback/failback/apply called without `--yes`
- `doctor check --deep` or `monitor summary --strict` fail
