# `services redis sync-config`

## Amac

Native Redis icin `PLUME_REDIS_PORT`, `PLUME_REDIS_PASSWORD`, `PLUME_NATIVE_REDIS_BIND` degerlerini Homebrew/system `redis.conf` uzerine Plume include dosyasi ile uygulamak (Laradock `.env` → runtime parity).

## Kullanim

```bash
plumectl services redis sync-config
plumectl services redis sync-config --reload
plumectl services redis sync-config --dry-run
```

`services install|up|restart redis --mode=native` sirasinda config sync otomatik calisir (`PLUME_NATIVE_REDIS_MANAGE_CONFIG=true`, varsayilan).

## Parametreler

- `--dry-run`: hedef dosyalar ve port/sifre ozetini yazdir; degisiklik yapmaz
- `--reload`: sync sonrasi `brew services restart redis` (veya systemd `redis`)

## Env

| Degisken | Aciklama | Varsayilan |
|----------|----------|------------|
| `PLUME_REDIS_PORT` | Redis dinleme portu | `6379` |
| `PLUME_REDIS_PASSWORD` | `requirepass`; `null`/bos = sifresiz | `secret_redis` |
| `PLUME_NATIVE_REDIS_BIND` | `bind` adresi | `127.0.0.1` |
| `PLUME_NATIVE_REDIS_MANAGE_CONFIG` | Config yonetimini ac/kapat | `true` |
| `PLUME_NATIVE_REDIS_MAIN_CONF` | Ana redis.conf yolu override | brew/apt otomatik |

`services up redis` sirasinda preferred port (`REDIS_PORT`, varsayilan 6379) doluysa Plume +1 dener; listener zaten `redis-server` ise portu korur (D-148). Laravel `.env` ile ayni portu tutmak icin `REDIS_PORT=6379` birakip `down` + `up` yeter.

Uretilen dosya: `$(plume_state_dir)/native/redis/plume-redis.conf` — ana config'e `include` ile eklenir.

## Cikti / exit-code

- `0`: basarili
- `2`: redis kurulu degil, ana config bulunamadi, veya `PLUME_NATIVE_REDIS_MANAGE_CONFIG=false`

## Ornekler

```bash
# Plume global env
./plume.sh env set PLUME_REDIS_PASSWORD=deneme
./plume.sh services redis sync-config --reload

# Laravel projesi (.env) ile ayni sifre
# REDIS_PASSWORD=deneme

./plume.sh services credentials redis --mode=native
./plume.sh services restart redis --mode=native
```

## Hata senaryolari

- Redis Plume disinda kurulu ve config patch edilmedi → Laravel AUTH hatasi; `services redis sync-config --reload` calistirin.
- `PLUME_REDIS_ENABLED=false` iken servis ayaga kalkmaz; `services.yml` veya env ile enable edin.

Iliskili: [services-env.md](services-env.md), [env-contract.md](../operations/env-contract.md).
