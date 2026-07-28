# Phase 15 — Scheduler, queue ops & manifest alignment

Hedef: Laravel zamanlayici ve kuyruk operasyonlari (Herd parity) + manifest’te horizon/php_worker sinirlari.

## Status

**in-progress** (tracker: [phase-tracker.md](../phase-tracker.md))

## Checklist

- [x] `schedule status|list|run-once`, `queue status|list` (D-111, D-112)
- [x] Release smoke: `phase15_scheduler_queue_smoke.sh`
- [x] Horizon / php_worker / supervisor: manifest env + native vs docker-lite dokumantasyonu (D-113)
- [x] Plume-managed crontab install (`schedule cron-install`; D-114)
- [ ] Phase 15 gate: checklist tamam + decision log + `--release` yesil

## Alt dokumanlar

- [phase-15-scheduler-queue.md](./phase-15-scheduler-queue.md)
- [phase-15-backlog-plume-yml-dockerlite.md](./phase-15-backlog-plume-yml-dockerlite.md) (plume.yml v2 — ayri trigger)

## Komutlar

- [schedule.md](../../docs/commands/schedule.md)
- [queue.md](../../docs/commands/queue.md)
