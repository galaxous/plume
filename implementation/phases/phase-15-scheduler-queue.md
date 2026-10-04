# Phase 15 — Scheduler & queue ops (closed / archive)

> **Archive:** Phase 15 closed on **2026-07-28**. Official gate: [phase-15.md](./phase-15.md) (`done`, D-115). New work: [phase-15-backlog-plume-yml-dockerlite.md](./phase-15-backlog-plume-yml-dockerlite.md).

Herd/Laradock parity: Laravel `schedule:run`, queue workers, Horizon — operational commands for native and docker-lite.

## Checklist

- [x] `plume schedule status` / `plume queue status` MVP (project path resolution, cron hint, horizon/supervisor runtime lines)
- [x] `schedule list`, `schedule run-once`, `queue list` (queue:failed); `--dry-run` on run-once
- [x] `schedule cron-install` / `--remove` / `--dry-run`; marker `# plume-laravel-schedule-cron` (D-114)
- [x] Manifest: `services.horizon` / `php_worker` native provision limits documented; alignment with docker-lite `laravel-horizon` (D-113)
- [x] Smoke: hermetic mock site + `artisan` stub; `tests/phase15_scheduler_queue_smoke.sh` in the release chain
- [x] `docs/commands/schedule.md`, `docs/commands/queue.md` + D-111 decision record; release smoke gate

## Links

- [phase-15-backlog-plume-yml-dockerlite.md](./phase-15-backlog-plume-yml-dockerlite.md)
- [services.md](../../docs/commands/services.md) (horizon / supervisor dependency)
- [schedule.md](../../docs/commands/schedule.md)
- [queue.md](../../docs/commands/queue.md)
