# `services` horizon / supervisor (native)

## Amac

Laradock `laravel-horizon` container’i gibi native queue worker: Supervisor process manager + `php artisan horizon`. Redis ayri servis (`services up redis`).

## Kullanim

```bash
SUPERVISOR_ENABLED=true
HORIZON_ENABLED=true
# optional: PLUME_HORIZON_PATH=/abs/laravel-app
./plume.sh services up supervisor --mode=native
./plume.sh services up horizon --mode=native
./plume.sh services status @queue --mode=native
./plume.sh services down horizon --mode=native
```

## Parametreler

- `--mode=native`
- `PLUME_HORIZON_PATH`: Laravel kok (artisan). Bos ise ilk kayitli site veya cwd.
- `PLUME_HORIZON_REQUIRE_SUPERVISOR` (varsayilan `true`): `up horizon` supervisor enable ister
- PHP: site `php_version` veya `PLUME_PHP_DEFAULT_VERSION`

Plume, Homebrew/apt `supervisor` paketini kurar; **sistem** `brew services supervisor` kullanmaz. `supervisord` state altinda calisir (`~/.config/plume/state/native/supervisor/`).

## Cikti / exit-code

- `0`: install/start basarili; status `health=healthy` (program RUNNING)
- `2`: supervisor kapali, artisan bulunamadi, veya supervisord yok

## Ornekler

```bash
./plume.sh services use mariadb --mode=native
./plume.sh services up redis --mode=native
./plume.sh services up @queue --mode=native
```

Laravel `.env`: `QUEUE_CONNECTION=redis`, `REDIS_HOST=127.0.0.1`.

## Hata senaryolari

- `horizon requires supervisor` — `SUPERVISOR_ENABLED=true`
- `no Laravel project with artisan` — `PLUME_HORIZON_PATH` veya `site add`
- `php_worker` native’de hâlâ registry-only; `queue:work` icin docker-lite veya manuel
