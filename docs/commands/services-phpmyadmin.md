# Native phpMyAdmin

## Amac

macOS/Linux native modda phpMyAdmin: `brew install phpmyadmin` (veya apt), `PMA_*` env → `config.inc.php`, `php -S 127.0.0.1:8081`.

## Kullanim

```bash
# ~/.config/plume/.env
PLUME_PHPMYADMIN_ENABLED=true
PLUME_PHPMYADMIN_PORT=8081
PMA_ARBITRARY=1
PMA_AUTH_TYPE=cookie

./plume.sh services install phpmyadmin --mode=native
./plume.sh services up phpmyadmin --mode=native
# Login formu: Server + kullanici + sifre (Laradock gibi)
# native: dropdown etiketi mariadb|mysql; TCP host her zaman 127.0.0.1 (port PLUME_*_PORT)
# docker-lite: Server = mariadb veya mysql (container hostname)
```

Her aktif engine icin ayri phpMyAdmin server kaydi uretilir (`verbose=mariadb|mysql`, `host=127.0.0.1`, port=`PLUME_MARIADB_PORT` / `PLUME_MYSQL_PORT`). Dropdown'da yalnizca **calisan** (veya enabled) engine'ler gorunur.

**macOS Homebrew:** `mariadb` ve `mysql` formulalari cakisir (ayni binary); ikisini birden native brew ile calistiramazsin. Laradock'taki gibi ikisi birden gerekiyorsa: biri native, digeri `docker-lite`, veya yalnizca `mariadb` native.

`/etc/hosts` icine `127.0.0.1 mariadb mysql` yazmak opsiyoneldir (`PLUME_NATIVE_DB_HOSTS_SYNC`); phpMyAdmin config artik hostname'e bagimli degildir (D-142).
## Parametreler

| Degisken | Aciklama | Varsayilan |
|----------|----------|------------|
| `PLUME_PHPMYADMIN_PORT` / `PMA_PORT` | HTTP port | `8081` |
| `PMA_ARBITRARY` | Ek serbest Server alani + Laradock parity | `1` |
| `PMA_AUTH_TYPE` | `cookie` (login formu) veya `config` (otomatik giris) | `cookie` |
| `PLUME_MARIADB_PORT` / `PLUME_MYSQL_PORT` | Engine basina TCP port (ikisi birlikte farkli olmali) | `3306` / `3307` |
| `PLUME_NATIVE_DB_HOSTS_SYNC` | `mariadb`/`mysql` hostname → `127.0.0.1` | `true` |
| `PMA_DB_ENGINE` | **docker-lite:** compose `depends_on`; **native arbitrary:** opsiyonel | `mariadb` |
| `PMA_HOST` / `PMA_DB_PORT` | Yalnizca `PMA_ARBITRARY=0` iken sabit hedef | — |
| `PMA_USER` / `PMA_PASSWORD` | `services credentials` ipucu | MariaDB root |

- `state/native/phpmyadmin/htdocs/` — phpMyAdmin dosyalari (brew/apt'ten kopya)
- `state/native/phpmyadmin/htdocs/config.inc.php` — Plume uretir

## Cikti / exit-code

- `services url phpmyadmin`: `url=http://127.0.0.1:8081`
- `services credentials phpmyadmin`: db host/port/user/password + http_port
- `0`: basarili
- `2`: phpmyadmin kurulu degil, php yok, veya DB engine disabled

## Ornekler

```bash
open http://127.0.0.1:8081
./plume.sh services credentials phpmyadmin --mode=native
```

## Hata senaryolari

- **8081 connection refused**: `services up phpmyadmin` calistirilmamis veya `brew install phpmyadmin` eksik.
- **DB login failed**: `PMA_PASSWORD` ile `PLUME_MARIADB_ROOT_PASSWORD` uyumsuz; `.env` esitle + `services restart mariadb`.
- **getaddrinfo for mariadb failed**: eski config hostname kullaniyordu; `services restart phpmyadmin` (D-142: host=127.0.0.1). Login'de Server dropdown'dan `mariadb` sec, sifre = `MARIADB_ROOT_PASSWORD`.
- **services.yml disabled**: `.env` (`PLUME_PHPMYADMIN_ENABLED=true`) manifest uzerinde kazanir.
