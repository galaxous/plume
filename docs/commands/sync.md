# `sync` Commands

## Amac

Canli runtime durumunu (ozellikle docker-lite) state dosyalari + SQLite ile senkron tutmak.

## Kullanim

```bash
./plume.sh sync state --mode=docker-lite
./plume.sh sync state --mode=docker-lite --path=/abs/project
./plume.sh sync state --mode=laradock-bridge
./plume.sh sync state --mode=laradock-bridge --path=/abs/laradock

./plume.sh sync cron install --mode=docker-lite
./plume.sh sync cron status
./plume.sh sync cron remove
./plume.sh sync cron run --mode=docker-lite
```

## Notlar

- `sync state` docker-lite'ta canli container durumunu okuyup `services_runtime_*.env`, `services_ports_*.env` ve `plume-state.db` tablolarini gunceller.
- `sync state` laradock-bridge'de explicit Laradock context ister:
  - `--path=/abs/laradock`
  - veya `mode path set laradock-bridge /abs/laradock`
- Laradock-bridge sync'te source-of-truth canli `docker compose` durumudur.
- Laradock-bridge sync port introspection davranisi:
  - servis portlari tekil degil coklu host port olarak da yazilabilir (`workspace=2222,3000`, `nginx=80,443`)
  - web servisleri icin `web_https` anahtari da senkronize edilir.
- `sync cron install` varsayilan olarak saatlik cron yazar (`0 * * * *`).
- Zamanlama `--schedule="15 * * * *"` ile degistirilebilir.
