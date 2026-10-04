# Phase 21 — Queue honesty + ecosystem backlog

## Objective

Native `horizon` / `supervisor` / `php_worker` must not lie (`health=registry` + WARN). Document meilisearch/minio as toggle-only; native driver backlog.

## Status

- `done` (2026-08-12) — honesty + backlog document; host supervisor install **not** included (stretch)
- Tracker: [phase-tracker.md](../phase-tracker.md)
- ADR: D-146

## MVP Scope

- [x] `services up horizon` native: WARN registry-only; exit 0 (do not break existing smokes)
- [x] `services status horizon` → `health=registry`
- [x] meilisearch / minio: toggle-only WARN; `health=registry`
- [x] Backlog: brew `supervisor` host, meilisearch/minio native driver, Reverb/Soketi, Docker-lite unfreeze (P1, after native P0)

## Out of scope (later phase)

- Real host supervisor + horizon worker
- meilisearch / minio brew/apt driver
- Docker-lite unfreeze

## Gate Checklist

- [x] Honesty smoke: `phase21_queue_honesty_smoke.sh`
- [x] Decision log D-146
- [x] Tracker + future-roadmap

## Reference

- [native-service-contract.md](../../docs/operations/native-service-contract.md)
- [docs/operations/services-manifest.md](../../docs/operations/services-manifest.md) (D-113)
