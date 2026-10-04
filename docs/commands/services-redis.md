# `services redis sync-config`

## Purpose

Apply `PLUME_REDIS_PORT`, `PLUME_REDIS_PASSWORD`, and `PLUME_NATIVE_REDIS_BIND` to Homebrew/system `redis.conf` via a Plume include file for native Redis (Laradock `.env` → runtime parity).

## Usage

```bash
plumectl services redis sync-config
plumectl services redis sync-config --reload
plumectl services redis sync-config --dry-run
```

Config sync runs automatically during `services install|up|restart redis --mode=native` (`PLUME_NATIVE_REDIS_MANAGE_CONFIG=true`, default).

## Parameters

- `--dry-run`: print target files and port/password summary; make no changes
- `--reload`: after sync, `brew services restart redis` (or systemd `redis`)

## Env

| Variable | Description | Default |
|----------|-------------|---------|
| `PLUME_REDIS_PORT` | Redis listen port | `6379` |
| `PLUME_REDIS_PASSWORD` | `requirepass`; `null`/empty = no password | `secret_redis` |
| `PLUME_NATIVE_REDIS_BIND` | `bind` address | `127.0.0.1` |
| `PLUME_NATIVE_REDIS_MANAGE_CONFIG` | Enable/disable config management | `true` |
| `PLUME_NATIVE_REDIS_MAIN_CONF` | Override main redis.conf path | brew/apt auto |

During `services up redis`, if the preferred port (`REDIS_PORT`, default 6379) is taken, Plume tries +1; if the listener is already `redis-server`, it keeps the port (D-148). To keep the same port as Laravel `.env`, leave `REDIS_PORT=6379` and run `down` + `up`.

Generated file: `$(plume_state_dir)/native/redis/plume-redis.conf` — added to the main config via `include`.

## Output / exit-code

- `0`: success
- `2`: redis not installed, main config not found, or `PLUME_NATIVE_REDIS_MANAGE_CONFIG=false`

## Examples

```bash
# Plume global env
./plume.sh env set PLUME_REDIS_PASSWORD=deneme
./plume.sh services redis sync-config --reload

# Same password as Laravel project (.env)
# REDIS_PASSWORD=deneme

./plume.sh services credentials redis --mode=native
./plume.sh services restart redis --mode=native
```

## Error scenarios

- Redis installed outside Plume and config not patched → Laravel AUTH error; run `services redis sync-config --reload`.
- With `PLUME_REDIS_ENABLED=false` the service will not start; enable via `services.yml` or env.

Related: [services-env.md](services-env.md), [env-contract.md](../operations/env-contract.md).
