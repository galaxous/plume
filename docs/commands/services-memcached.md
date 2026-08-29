# `services` memcached (native)

## Amac

Laradock `memcached` container’i gibi native cache: enable → up → credentials. Laravel `.env`: `MEMCACHED_HOST=127.0.0.1`.

## Kullanim

```bash
MEMCACHED_ENABLED=true
./plume.sh services up memcached --mode=native
./plume.sh services credentials memcached --mode=native
./plume.sh services status memcached --mode=native
```

## Parametreler

- `--mode=native`
- Port: `PLUME_MEMCACHED_PORT` / `MEMCACHED_PORT` (varsayilan `11211`)
- OS: brew `memcached`; apt/dnf `memcached` + systemd

## Cikti / exit-code

- credentials: `host=127.0.0.1` `port=11211`
- `0` basarili; `2` native olmayan mode veya kurulum hatasi

## Ornekler

```bash
./plume.sh services up @cache --mode=native
./plume.sh services env show memcached --mode=native
```

## Hata senaryolari

- Port dolu: allocate `+1..+50` (registry port contract)
- Linux: systemd yoksa start fail
