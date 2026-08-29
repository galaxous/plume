# Phase 22 — Native supervisor + Horizon worker

## Objective

Native queue stack Laradock `laravel-horizon` gibi: brew/apt `supervisor` binary + Plume supervisord + `php artisan horizon`. Redis zaten native driver; bu faz worker’i gercek process yapar (D-146 registry-only kalkar).

## Status

- `done` (2026-08-18)
- Tracker: [phase-tracker.md](../phase-tracker.md)
- ADR: D-147

## MVP Scope

- [x] `supervisor` native driver: Plume-owned `supervisord` (state dir), detach (D-140)
- [x] `horizon` program: `php artisan horizon` in `PLUME_HORIZON_PATH` or first site with `artisan`
- [x] `services up horizon` requires supervisor (existing); live `health=healthy` when RUNNING
- [x] `php_worker` / meilisearch / minio: registry-only kalir (D-146)
- [x] Smoke: `phase22_native_horizon_smoke.sh`

## Gate Checklist

- [x] MVP scope complete
- [x] Decision log D-147
- [x] `docs/commands/services-horizon.md`
- [x] OS matrix + support matrix
- [x] Tracker satiri

## Referans

- [native-service-contract.md](../../docs/operations/native-service-contract.md)
- [docs/commands/services-horizon.md](../../docs/commands/services-horizon.md)
