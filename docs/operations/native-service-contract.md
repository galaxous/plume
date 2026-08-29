# Native service contract (Laradock-container UX)

Kaynak: D-144. Agent kurallari: [AGENTS.md](../../AGENTS.md) §1, §9.

Native bir servis Laradock container’i gibi davranir:

```bash
REDIS_ENABLED=true
./plume.sh services up redis --mode=native
./plume.sh services status redis --mode=native   # running=true health=healthy | yalan yok
./plume.sh services credentials redis --mode=native
```

Laravel `.env`: `127.0.0.1` (container hostname yok). Terminal kapaninca HTTP daemon olmez (D-140).

## Checklist (her yeni veya yenilenen native servis)

Ayni PR’de:

1. Registry: `plume_service_names` + `PLUME_*_ENABLED` + Laradock kisa ad ([stack_service_env.sh](../../lib/common/stack_service_env.sh))
2. Manifest satiri: [templates/services.yml.example](../../templates/services.yml.example)
3. Driver: install / start / stop / live health / (HTTP ise) url / credentials
4. HTTP UI: `plume_native_detach_daemon` (D-140); TCP host `127.0.0.1` (D-142)
5. Health: canli probe; PID oluyse `running=false` + `stopped`; stdout yut (D-143)
6. Grup: `@web` / `@db` / `@cache` / `@queue` / `@core` (uygun olani)
7. Docs: `docs/commands/services-<name>.md` + [native-stack-os-matrix.md](./native-stack-os-matrix.md) + [service-support-matrix.md](./service-support-matrix.md)
8. Hermetik smoke (`PATH=${MOCK_BIN}:/usr/bin:/bin`) + D-xxx + phase-tracker

## Gruplar (native)

| Grup | Uyeler (enabled filtreli up) |
|------|------------------------------|
| `@web` | `web` (aktif driver: nginx/apache2/caddy; registry adi `web`) |
| `@db` | mariadb, mysql, postgres, phpmyadmin, pgadmin |
| `@cache` | redis, mongodb, rabbitmq, memcached, mongo_webui, redis_webui |
| `@queue` | php_worker (registry-only), horizon, supervisor (native host, D-147) |
| `@core` | php, composer, web drivers, DB engines, redis, phpmyadmin, pgadmin, mailpit — **queue yok** |

`services up @core` yalnizca `enabled=true` uyeleri baslatir. Native brew: mariadb+mysql XOR (D-128). Engine secimi: `services use mariadb|mysql|postgres`.

## Status gercekligi

- `healthy`: live probe gecti
- `stopped`: enabled ama process/port yok (stale PID dahil)
- `starting`: HTTP daemon PID canli, HTTP henuz 2xx/3xx degil
- `registry`: php_worker / meilisearch / minio — host daemon yok
- `disabled`: toggle false

## Referans

- [services-use.md](../commands/services-use.md)
- [services.md](../commands/services.md)
- [services-horizon.md](../commands/services-horizon.md)
