# Phase 17 — Native Stack Host Parity

## Objective

Native modda Laradock seviyesinde stack servis lifecycle: DB, cache/broker ve web UI servisleri icin macOS/Linux host provision, health/logs/url/credentials CLI.

## Status

- `done` (2026-08-04)
- Tracker: [phase-tracker.md](../phase-tracker.md)
- ADR: D-119 (scope), D-120 (gate)

## MVP Scope

- [x] OS matrisi: AGENTS.md §9 + [native-stack-os-matrix.md](../../docs/operations/native-stack-os-matrix.md)
- [x] Driver katmani: `lib/services/native_host_service_drivers.sh`
- [x] Servisler: mariadb, mysql, postgres, phpmyadmin, redis, mongodb, rabbitmq, mongo_webui, redis_webui
- [x] CLI: `services url`, `services credentials`; `@db` / `@cache` native gruplari; `--no-provision`
- [x] Auto-provision: enabled servis + native `services up` (D-119)
- [x] Hermetik smoke: phase17_* (mock brew/apt/systemctl)

## Gate Checklist

- [x] MVP scope complete
- [x] `./tests/run_smoke_suite.sh --release` yesil
- [x] Decision log D-120
- [x] Tracker `done`

## Referans

- [lib/services/native_host_service_drivers.sh](../../lib/services/native_host_service_drivers.sh)
- [docs/commands/services-url.md](../../docs/commands/services-url.md)
