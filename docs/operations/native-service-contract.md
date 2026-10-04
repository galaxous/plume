# Native service contract (Laradock-container UX)

Source: D-144. Agent rules: [AGENTS.md](../../AGENTS.md) §1, §9.

A native service behaves like a Laradock container:

```bash
REDIS_ENABLED=true
./plume.sh services up redis --mode=native
./plume.sh services status redis --mode=native   # running=true health=healthy | no lies
./plume.sh services credentials redis --mode=native
```

Laravel `.env`: `127.0.0.1` (no container hostname). Closing the terminal does not kill the HTTP daemon (D-140).

## Checklist (every new or refreshed native service)

In the same PR:

1. Registry: `plume_service_names` + `PLUME_*_ENABLED` + Laradock short name ([stack_service_env.sh](../../lib/common/stack_service_env.sh))
2. Manifest row: [templates/services.yml.example](../../templates/services.yml.example)
3. Driver: install / start / stop / live health / (if HTTP) url / credentials
4. HTTP UI: `plume_native_detach_daemon` (D-140); TCP host `127.0.0.1` (D-142)
5. Health: live probe; if PID is dead then `running=false` + `stopped`; swallow stdout (D-143)
6. Group: `@web` / `@db` / `@cache` / `@queue` / `@core` (whichever fits)
7. Docs: `docs/commands/services-<name>.md` + [native-stack-os-matrix.md](./native-stack-os-matrix.md) + [service-support-matrix.md](./service-support-matrix.md)
8. Hermetic smoke (`PATH=${MOCK_BIN}:/usr/bin:/bin`) + D-xxx + phase-tracker

## Groups (native)

| Group | Members (enabled-filtered up) |
|------|------------------------------|
| `@web` | `web` (active driver: nginx/apache2/caddy; registry name `web`) |
| `@db` | mariadb, mysql, postgres, phpmyadmin, pgadmin |
| `@cache` | redis, mongodb, rabbitmq, memcached, mongo_webui, redis_webui |
| `@queue` | php_worker (registry-only), horizon, supervisor (system-primary, D-149) |
| `@core` | php, composer, web drivers, DB engines, redis, phpmyadmin, pgadmin, mailpit — **no queue** |

`services up @core` starts only `enabled=true` members. Native brew: mariadb+mysql XOR (D-128). Engine selection: `services use mariadb|mysql|postgres`.

## Status truth

- `healthy`: live probe passed
- `stopped`: enabled but no process/port (including stale PID)
- `starting`: HTTP daemon PID alive, HTTP not yet 2xx/3xx
- `registry`: php_worker / meilisearch / minio — no host daemon
- `disabled`: toggle false

## Reference

- [services-use.md](../commands/services-use.md)
- [services.md](../commands/services.md)
- [services-horizon.md](../commands/services-horizon.md)
