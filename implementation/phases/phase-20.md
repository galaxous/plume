# Phase 20 — Native cache/broker contract (mongodb, rabbitmq, memcached, webuis)

## Objective

Laravel’de sik acilan cache/broker opsiyonelleri native service contract (D-144) ile ayni UX: enable → up → credentials/url.

## Status

- `done` (2026-08-12)
- Tracker: [phase-tracker.md](../phase-tracker.md)
- ADR: D-145

## MVP Scope

- [x] mongodb + mongo_webui: credentials, 127.0.0.1, detach HTTP
- [x] rabbitmq management `services url`
- [x] memcached native brew/apt/dnf driver + credentials
- [x] redis_webui / mongo_webui smoke
- [x] OS matrix + command docs

## Gate Checklist

- [x] MVP scope complete
- [x] `phase20_native_cache_broker_smoke.sh`
- [x] Decision log D-145
- [x] Tracker satiri

## Referans

- [native-service-contract.md](../../docs/operations/native-service-contract.md)
- [docs/commands/services-memcached.md](../../docs/commands/services-memcached.md)
