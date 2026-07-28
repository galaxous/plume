# Phase 15 — Scheduler, Queue Ops & Manifest Alignment

## Objective

Laravel zamanlayici ve kuyruk operasyonlari (Herd parity) + manifest’te `horizon` / `php_worker` native sinirlari ve docker-lite hizalama.

## Status

- `done` (started: 2026-07-28, completed: 2026-07-28)
- Tracker: [phase-tracker.md](../phase-tracker.md)
- Kapanis karari: **D-115**; dilimler **D-111**–**D-114**
- Kapsam disi: [phase-15-backlog-plume-yml-dockerlite.md](./phase-15-backlog-plume-yml-dockerlite.md) (`plume.yml` v2, docker-lite derinlestirme)

## Scope Checklist

- [x] `schedule status|list|run-once`, `queue status|list` (D-111, D-112)
- [x] Plume-managed crontab: `schedule cron-install` / `--remove` / `--dry-run` (D-114)
- [x] Horizon / php_worker / supervisor: manifest env + native vs docker-lite dokumantasyonu (D-113)

## Test Checklist

- [x] Hermetik mock site + `artisan` stub: `tests/phase15_scheduler_queue_smoke.sh`
- [x] Release zinciri: `./tests/run_smoke_suite.sh --release` (runner + CI workflow hizali)

## Documentation Checklist

- [x] [schedule.md](../../docs/commands/schedule.md), [queue.md](../../docs/commands/queue.md)
- [x] [services-manifest.md](../../docs/operations/services-manifest.md) (horizon sinirlari)
- [x] [release-readiness.md](../../docs/operations/release-readiness.md) (phase 15 adimi)
- [x] Decision log D-111–D-115

## Gate Checklist (Mandatory)

- [x] Feature scope complete
- [x] Tests pass (`--release` / `--ci`)
- [x] Decision log updated (D-115)
- [x] Tracker satiri `done` + tamamlanma tarihi

## Alt dokumanlar

- [phase-15-scheduler-queue.md](./phase-15-scheduler-queue.md) (detay checklist; **kapandi**)
- [phase-15-backlog-plume-yml-dockerlite.md](./phase-15-backlog-plume-yml-dockerlite.md)
