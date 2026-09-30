# `services` horizon / supervisor (native)

## Amac

Laradock `laravel-horizon` container’i gibi native queue worker: Supervisor process manager + `php artisan horizon`. Redis ayri servis (`services up redis`).

**Cok proje:** Her site kaydi icin ayri supervisor programi (`plume-horizon-<site-id>`, D-150). Global `PLUME_HORIZON_PATH` yalnizca legacy fallback.

**Operasyon:** Yalnizca `plumectl` / `./plume.sh` — `supervisorctl` veya `brew services` yazmaniz gerekmez (D-152).

## Kullanim

```bash
plumectl site update site-xxx --horizon
plumectl services up redis --mode=native
plumectl services up horizon --mode=native
plumectl services up horizon --site=site-xxx --mode=native
plumectl services down horizon --site=site-xxx --mode=native
plumectl services restart horizon --site=site-xxx
plumectl services status horizon
plumectl services logs horizon --tail=50
plumectl services logs horizon --site=site-xxx --tail=50
plumectl doctor supervisor --strict
plumectl services supervisor upgrade --force --yes
plumectl services status @queue --mode=native
```

## Parametreler

- `--mode=native`
- `--site=<site-id>`: yalnizca belirtilen site icin horizon programi yaz/baslat/durdur/log
- Site kaydi `horizon: true`: `site add|update --horizon` / `--no-horizon`
- `PLUME_HORIZON_PATH` (legacy): horizon-enabled site yoksa tek `plume-horizon` programi
- `PLUME_HORIZON_REQUIRE_SUPERVISOR` (varsayilan `true`): `up horizon` supervisor enable ister
- PHP: site `php_version` veya `PLUME_PHP_DEFAULT_VERSION`

Plume, Homebrew/apt `supervisor` paketini kurar; **sistem** supervisor kullanilir. Program conf OS drop-in dizinine yazilir (D-149). macOS’ta Homebrew include: `$(brew --prefix)/etc/supervisor.d/*.ini` (D-153). Bkz. [services-supervisor.md](./services-supervisor.md).

## Cikti / exit-code

- `0`: install/start basarili; status `health=healthy` (tum hedef programlar RUNNING)
- `2`: supervisor kapali, hedef site yok, artisan bulunamadi, veya health fail

Health fail oldugunda Plume otomatik diagnose basar: program status, worker log kuyrugu, Redis/.env ipucu ve sonraki `plumectl` adimlari.

## Ornekler

```bash
# tunnelion + baska proje
plumectl site add --path=/path/tunnelion --domain=tunnelion.test --horizon --publish
plumectl site add --path=/path/other --domain=other.test --horizon --publish
plumectl services up redis --mode=native
plumectl services up horizon --mode=native

# tek proje
plumectl services up horizon --site=site-1775207595-23239

# stopped / FATAL ise
plumectl doctor supervisor
plumectl services logs horizon --site=site-1775207595-23239 --tail=50
plumectl services restart horizon --site=site-1775207595-23239
```

Laravel `.env`: `QUEUE_CONNECTION=redis`, `REDIS_HOST=127.0.0.1` (Redis sifresi varsa `REDIS_PASSWORD` supervisor worker ile ayni olmali).

## Hata senaryolari

- `horizon requires supervisor` — `SUPERVISOR_ENABLED=true` / `plumectl services up supervisor`
- `no horizon targets` — en az bir site icin `--horizon` veya legacy `PLUME_HORIZON_PATH`
- `site has no Laravel project with artisan` — gecerli site path + `artisan`
- health `stopped` — `plumectl services logs horizon` (Redis auth, missing Horizon migrate, artisan hata)
- `php_worker` native’de hâlâ registry-only; `queue:work` icin docker-lite veya manuel
