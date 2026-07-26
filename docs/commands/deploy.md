# `deploy`

## Amac

Deploy akisini planlamak, kontrollu apply calistirmak ve sorun durumunda rollback/failback komutlarini kullanmak.

## Kullanim

```bash
plumectl deploy plan --mode=native
plumectl deploy apply --mode=native --dry-run
plumectl --yes deploy apply --mode=native --skip-backup --skip-reconcile
plumectl deploy rollback latest --mode=native --dry-run
plumectl --yes deploy rollback latest --mode=native
plumectl --yes deploy failback --mode=native
```

## Parametreler

- `plan`
  - `--mode=<native|docker-lite|laradock-bridge>`
- `apply`
  - `--mode=...`
  - `--dry-run`
  - `--skip-backup`
  - `--skip-health`
  - `--skip-reconcile` (macOS'ta root olmadan `services update` atlanabilir)
  - `--yes` (kritik onay; dry-run haric zorunlu)
- `rollback`
  - `<id|latest>`
  - `--mode=...`
  - `--dry-run`
- `failback`
  - `--mode=...`
  - `--dry-run`

## Cikti / Exit Codes

- `0`: basarili
- `1`: genel hata
- `2`: guard/parametre/backup yok, doctor/monitor gate fail

Apply adimlari (dry-run degil):

1. Pre-deploy backup (`--scope=config`, `--name=pre-deploy`) — `--skip-backup` ile atlanir
2. `doctor check --deep` — `--skip-health` ile atlanir
3. `services update` — `--skip-reconcile` ile atlanir
4. `monitor summary --strict`

## Ornekler

```bash
plumectl deploy plan --mode=laradock-bridge
plumectl --yes deploy apply --mode=native
plumectl --yes deploy rollback latest --mode=laradock-bridge
plumectl --yes deploy failback --mode=laradock-bridge
```

## Hata Senaryolari

- `latest` icin backup yok
- failback marker yok
- `--yes` olmadan rollback/failback/apply cagrisi
- `doctor check --deep` veya `monitor summary --strict` fail
