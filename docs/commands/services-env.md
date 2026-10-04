# `services env` / `services restart`

## Purpose

Manage connection/port/password settings for Redis, MongoDB, RabbitMQ, and web UI services via `.env` or CLI; apply changes to runtime.

## Usage

```bash
plumectl services env show redis --mode=native
plumectl services env set redis password=custom --mode=native
plumectl services env set redis password=custom --mode=native --restart
plumectl services restart redis --mode=native
plumectl env set PLUME_REDIS_PASSWORD=custom
```

## Parameters

- `--mode=native` (required; stack env MVP is native-only)
- `env show <service>`: `redis`, `mariadb`, `mysql`, `postgres`, `mongodb`, `rabbitmq`, `memcached`, `mongo_webui`, `redis_webui`, `mailpit`
- `env set <service> <assignment>`:
  - short key: `password=`, `port=`, `username=`, `management_port=`, `uri=`, …
  - or full key: `PLUME_REDIS_PASSWORD=...`
- `--restart`: after `env set`, stop+start affected services
- `restart <service|@group|all-enabled>`: after `.env` change, config sync + stop + start (native DB/broker)

For native DB/broker services (`mariadb`, `postgres`, `mongodb`, `rabbitmq`, `redis`), config file sync runs **automatically inside restart** (`PLUME_NATIVE_*_MANAGE_CONFIG=true`). A separate `sync-config` command is not required.

## Output / exit-code

- `env show`: `PLUME_*=value` lines
- `env set` / `env set KEY=VALUE`: updates global `~/.config/plume/.env`; restart suggestion is logged
- `0`: success
- `2`: unsupported service/assignment

## Examples

```bash
# Laradock-like defaults (.env.example)
PLUME_REDIS_PASSWORD=secret_redis
PLUME_MONGODB_USERNAME=root
PLUME_MONGODB_PASSWORD=example

./plume.sh services env show mongodb --mode=native
./plume.sh services env set mongodb password=prod_secret --mode=native --restart
./plume.sh services restart mongo_webui --mode=native
```

## Error scenarios

- Password/port changed while service is running but restart was not done → web UI or broker keeps old config; `services restart` is required.
- `env set` unknown short key → check valid keys with `services env show <svc>`.

Laradock mapping: [env-contract.md](../operations/env-contract.md#stack-service-env-laradock-mapping).
