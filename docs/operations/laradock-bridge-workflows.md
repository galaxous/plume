# Laradock Bridge Workflows

Bu runbook, `laradock-bridge` modunda guvenli ve tekrar edilebilir operasyon akisini tanimlar.

## 1. Bootstrap

```bash
plumectl mode use laradock-bridge
plumectl mode path set laradock-bridge /abs/laradock --force
plumectl services laradock check
```

Beklenen:

- path/compose/.env strict validation gecer
- `APP_CODE_PATH_CONTAINER=/var/www` dogrulanir
- desteklenen servis map'i compose icinden discover edilir

## 2. Desired Service Set

```bash
plumectl services config reset
plumectl services config add @core
plumectl services config add redis
plumectl services config show
```

Kurallar:

- `up/down all` sadece desired/resolved set uzerinden calisir.
- desired disi compose servisleri default olarak etkilenmez.

## 3. Lifecycle

```bash
plumectl services up all
plumectl services status --running
plumectl services health --running
plumectl services down all
```

Safe-order:

- `up all`: `db -> php -> queue -> web -> others`
- `down all`: `web -> queue -> php -> db -> others`

Failure rollback:

- `up all` sirasinda start hatasi olursa, bu komutta daha once baslatilan servisler ters sirada rollback stop edilir.

## 4. State Sync

```bash
plumectl sync state --mode=laradock-bridge
```

Notlar:

- source-of-truth canli compose/container durumudur
- runtime + port state env dosyalari ve SQLite cache guncellenir
- coklu host portlar snapshot'a yazilir (`workspace=2222,3000`, `nginx=80,443`)

## 5. Logs/Exec/Containers

```bash
plumectl services logs @web --running --tail=50
plumectl services logs workspace --watch
plumectl services exec workspace bash
plumectl services containers
```

Not:

- `logs --watch` = `--follow` alias'i
- `status/health --watch[=N]` periyodik yenileme + timestamp basar
