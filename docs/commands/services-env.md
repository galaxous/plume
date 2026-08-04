# `services env` / `services restart`

## Amac

Redis, MongoDB, RabbitMQ ve web UI servisleri icin baglanti/port/sifre ayarlarini `.env` veya CLI ile yonetmek; degisiklikleri runtime'a uygulamak.

## Kullanim

```bash
plumectl services env show redis --mode=native
plumectl services env set redis password=custom --mode=native
plumectl services env set redis password=custom --mode=native --restart
plumectl services restart redis --mode=native
plumectl env set PLUME_REDIS_PASSWORD=custom
```

## Parametreler

- `--mode=native` (zorunlu; stack env MVP native-only)
- `env show <service>`: `redis`, `mongodb`, `rabbitmq`, `mongo_webui`, `redis_webui`
- `env set <service> <assignment>`:
  - kisa anahtar: `password=`, `port=`, `username=`, `management_port=`, `uri=`, …
  - veya tam anahtar: `PLUME_REDIS_PASSWORD=...`
- `--restart`: `env set` sonrasi etkilenen servisleri stop+start
- `restart <service|@group|all-enabled>`: `.env` degisikliginden sonra npm web UI ve credential senkronu icin

## Cikti / exit-code

- `env show`: `PLUME_*=value` satirlari
- `env set` / `env set KEY=VALUE`: global `~/.config/plume/.env` guncellenir; restart onerisi loglanir
- `0`: basarili
- `2`: desteklenmeyen servis/assignment

## Ornekler

```bash
# Laradock benzeri varsayilanlar (.env.example)
PLUME_REDIS_PASSWORD=secret_redis
PLUME_MONGODB_USERNAME=root
PLUME_MONGODB_PASSWORD=example

./plume.sh services env show mongodb --mode=native
./plume.sh services env set mongodb password=prod_secret --mode=native --restart
./plume.sh services restart mongo_webui --mode=native
```

## Hata senaryolari

- Servis calisirken sifre/port degisti ama restart yapilmadi → web UI veya broker eski config ile calisir; `services restart` gerekir.
- `env set` bilinmeyen kisa anahtar → `services env show <svc>` ile gecerli anahtarlari kontrol edin.

Laradock esleme: [env-contract.md](../operations/env-contract.md#stack-service-env-laradock-mapping).
