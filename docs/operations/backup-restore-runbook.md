# Backup Restore Runbook

## 1. Backup Al

```bash
plumectl backup create --mode=<mode> --scope=all --name=before-change
plumectl backup list --mode=<mode>
```

## 2. Metadata Dogrula

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

## Notlar

- `backup restore` kritik komuttur; `--yes` zorunludur (dry-run haric).
- Restore sonrasi `monitor summary --strict` ile kritik issue kontrolu yapin.
