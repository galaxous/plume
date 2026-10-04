# Phase 15 — Scheduler, Queue Ops & Manifest Alignment

## Objective

Laravel scheduler and queue operations (Herd parity) + native limits for `horizon` / `php_worker` in the manifest and docker-lite alignment.

## Status

- `done` (started: 2026-07-28, completed: 2026-07-28)
- Tracker: [phase-tracker.md](../phase-tracker.md)
- Closeout decision: **D-115**; slices **D-111**–**D-114**
- Out of scope: [phase-15-backlog-plume-yml-dockerlite.md](./phase-15-backlog-plume-yml-dockerlite.md) (`plume.yml` v2, docker-lite deepening)

## Scope Checklist

- [x] `schedule status|list|run-once`, `queue status|list` (D-111, D-112)
- [x] Plume-managed crontab: `schedule cron-install` / `--remove` / `--dry-run` (D-114)
- [x] Horizon / php_worker / supervisor: manifest env + native vs docker-lite documentation (D-113)

## Test Checklist

- [x] Hermetic mock site + `artisan` stub: `tests/phase15_scheduler_queue_smoke.sh`
- [x] Release chain: `./tests/run_smoke_suite.sh --release` (runner + CI workflow aligned)

## Documentation Checklist

- [x] [schedule.md](../../docs/commands/schedule.md), [queue.md](../../docs/commands/queue.md)
- [x] [services-manifest.md](../../docs/operations/services-manifest.md) (horizon limits)
- [x] [release-readiness.md](../../docs/operations/release-readiness.md) (phase 15 step)
- [x] Decision log D-111–D-115

## Gate Checklist (Mandatory)

- [x] Feature scope complete
- [x] Tests pass (`--release` / `--ci`)
- [x] Decision log updated (D-115)
- [x] Tracker row `done` + completion date

## Sub-documents

- [phase-15-scheduler-queue.md](./phase-15-scheduler-queue.md) (detail checklist; **closed**)
- [phase-15-backlog-plume-yml-dockerlite.md](./phase-15-backlog-plume-yml-dockerlite.md)
