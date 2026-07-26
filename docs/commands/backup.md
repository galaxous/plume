# `backup`

## Amac

Plume state/config ve SQLite state verisini arsivleyip geri yuklemek.

## Kullanim

```bash
plumectl backup create --mode=native --scope=all
plumectl backup list --mode=native
plumectl backup show <backup-id>
plumectl backup restore <backup-id> --dry-run
plumectl --yes backup restore <backup-id>
```

## Parametreler

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

## Cikti / Exit Codes

- `0`: basarili
- `1`: genel hata
- `2`: gecersiz parametre/guard blokaji

## Ornekler

```bash
plumectl backup create --scope=config --name=pre-upgrade
plumectl backup list
plumectl backup show backup-pre-upgrade-20260403-120000
plumectl backup restore backup-pre-upgrade-20260403-120000 --dry-run
plumectl --yes backup restore backup-pre-upgrade-20260403-120000
```

## Hata Senaryolari

- Backup dosyasi bulunamiyor
- `--scope` gecersiz
- Restore icin `--yes` verilmedi
