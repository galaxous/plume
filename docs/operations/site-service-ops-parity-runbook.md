# Site/Service Ops Parity Runbook

Bu runbook, `native`, `docker-lite` ve `laradock-bridge` modlarinda ayni komut yuzeyi ile operasyon yapma adimlarini ozetler.

## 1. Mode Secimi

```bash
plumectl mode current
plumectl mode use native
plumectl mode use docker-lite
plumectl mode use laradock-bridge
```

## 2. Site Lifecycle (Ayni Komut Yuzeyi)

```bash
plumectl site add --path=/abs/project --domain=app.test --server=nginx --publish
plumectl site update <site-id> --domain=app.test,www.app.test --publish
plumectl site publish <site-id> --reload
plumectl site check <site-id>
plumectl site remove <site-id>
plumectl site modes
```

Dry-run:

```bash
plumectl site add --path=/abs/project --domain=app.test --server=nginx --dry-run
plumectl site publish <site-id> --dry-run
plumectl site remove <site-id> --dry-run
```

## 3. Service Ops (Ayni Komut Yuzeyi)

```bash
plumectl services supported --mode=native
plumectl services supported --mode=docker-lite
plumectl services supported --mode=laradock-bridge

plumectl services status --mode=native
plumectl services up --mode=native php
plumectl services down --mode=native php
```

## 4. Docker-Lite Compose Kurali

- `PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true` ise compose dosyasi zorunludur.
- Kaynak:
  - `mode path` ile kayitli docker-lite workspace path
  - veya calisma dizinindeki `docker-compose.yml` / `compose.yml`

## 5. Laradock Strict Kurali

- `PLUME_LARADOCK_STRICT=true` ise publish/reload oncesi su kontroller fail-fast yapar:
  - `PLUME_LARADOCK_PATH` var mi
  - compose dosyasi var mi (`PLUME_LARADOCK_COMPOSE_FILE` veya `<path>/docker-compose.yml`)
  - hedef container var ve running mi

## 6. Reload Semantics

- `site publish --reload` hedef servere gore reload dener (`nginx|apache2|caddy`).
- `PLUME_SITE_RELOAD_REQUIRED=true` ise reload basarisizligi komutu fail eder (`exit 2`).

## 7. Hosts Sync Semantics

- `PLUME_SITE_HOSTS_SYNC=true` ise hosts kaydi guncellenir.
- `PLUME_SITE_HOSTS_REQUIRED=true` ise hosts yazma basarisizsa publish/update fail olur.

## 8. Mode Visibility

- `plumectl site modes` bir sitenin hangi mode'da kayitli oldugunu toplu listeler.
- Bu gorunum, mode degisimi sonrasi drift kontrolu icin kullanilir.
- Bir site `site update --mode=<mode>` ile tasindiginda eski mode'a ait snippet/cache artefact'lari temizlenir.

## 9. Rollback Semantics

- `site update --publish` adiminda publish basarisiz olursa record rollback edilir.
- Dry-run adimlari dosya/registry degisikligi yapmaz.
