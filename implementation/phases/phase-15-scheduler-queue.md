# Phase 15 — Scheduler & queue ops (backlog)

Herd/Laradock parity: Laravel `schedule:run`, queue workers, Horizon — native ve docker-lite icin operasyonel komutlar.

## Checklist

- [x] `plume schedule status` / `plume queue status` MVP (proje yolu cozumleme, cron ipucu, horizon/supervisor runtime satirlari)
- [x] `schedule list`, `schedule run-once`, `queue list` (queue:failed); `--dry-run` on run-once; plume-managed cron install backlog
- [x] Manifest: `services.horizon` / `php_worker` native provision sinirlari dokumante; docker-lite `laravel-horizon` ile hizalama (D-113)
- [x] Smoke: hermetik mock site + `artisan` stub; `tests/phase15_scheduler_queue_smoke.sh` release zincirinde
- [x] `docs/commands/schedule.md`, `docs/commands/queue.md` + D-111 karar kaydi; release smoke gate

## Baglantilar

- [phase-15-backlog-plume-yml-dockerlite.md](./phase-15-backlog-plume-yml-dockerlite.md)
- [services.md](../../docs/commands/services.md) (horizon / supervisor bagimliligi)
- [schedule.md](../../docs/commands/schedule.md)
- [queue.md](../../docs/commands/queue.md)
