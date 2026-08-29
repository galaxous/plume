# Phase 21 — Queue honesty + ecosystem backlog

## Objective

Native `horizon` / `supervisor` / `php_worker` yalan soylemesin (`health=registry` + WARN). meilisearch/minio toggle-only olarak dokumante; native driver backlog.

## Status

- `done` (2026-08-12) — honesty + backlog dokumani; host supervisor kurulumu **yok** (stretch)
- Tracker: [phase-tracker.md](../phase-tracker.md)
- ADR: D-146

## MVP Scope

- [x] `services up horizon` native: WARN registry-only; exit 0 (mevcut smoke’lar kirilmasin)
- [x] `services status horizon` → `health=registry`
- [x] meilisearch / minio: toggle-only WARN; `health=registry`
- [x] Backlog: brew `supervisor` host, meilisearch/minio native driver, Reverb/Soketi, Docker-lite unfreeze (P1, native P0 sonrasi)

## Kapsam disi (sonraki faz)

- Gercek host supervisor + horizon worker
- meilisearch / minio brew/apt driver
- Docker-lite unfreeze

## Gate Checklist

- [x] Honesty smoke: `phase21_queue_honesty_smoke.sh`
- [x] Decision log D-146
- [x] Tracker + future-roadmap

## Referans

- [native-service-contract.md](../../docs/operations/native-service-contract.md)
- [docs/operations/services-manifest.md](../../docs/operations/services-manifest.md) (D-113)
