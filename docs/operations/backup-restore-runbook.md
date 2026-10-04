# Backup Restore Runbook

## 1. Take a Backup

```bash
plumectl backup create --mode=<mode> --scope=all --name=before-change
plumectl backup list --mode=<mode>
```

## 2. Verify Metadata

```bash
plumectl backup show <backup-id>
```

## 3. Restore Dry-Run

```bash
plumectl backup restore <backup-id> --mode=<mode> --dry-run
```

## 4. Restore

```bash
plumectl --yes backup restore <backup-id> --mode=<mode>
plumectl monitor summary --mode=<mode>
```

## Notes

- `backup restore` is a critical command; `--yes` is required (except dry-run).
- After restore, check critical issues with `monitor summary --strict`.
