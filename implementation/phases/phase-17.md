# Phase 17 — Native Stack Host Parity

## Objective

Laradock-level stack service lifecycle in native mode: macOS/Linux host provision for DB, cache/broker, and web UI services, plus health/logs/url/credentials CLI.

## Status

- `done` (2026-08-04)
- Tracker: [phase-tracker.md](../phase-tracker.md)
- ADR: D-119 (scope), D-120 (gate)

## MVP Scope

- [x] OS matrix: AGENTS.md §9 + [native-stack-os-matrix.md](../../docs/operations/native-stack-os-matrix.md)
- [x] Driver layer: `lib/services/native_host_service_drivers.sh`
- [x] Services: mariadb, mysql, postgres, phpmyadmin, redis, mongodb, rabbitmq, mongo_webui, redis_webui
- [x] CLI: `services url`, `services credentials`; `@db` / `@cache` native groups; `--no-provision`
- [x] Auto-provision: enabled service + native `services up` (D-119)
- [x] Hermetic smoke: phase17_* (mock brew/apt/systemctl)

## Gate Checklist

- [x] MVP scope complete
- [x] `./tests/run_smoke_suite.sh --release` green
- [x] Decision log D-120
- [x] Tracker `done`

## Reference

- [lib/services/native_host_service_drivers.sh](../../lib/services/native_host_service_drivers.sh)
- [docs/commands/services-url.md](../../docs/commands/services-url.md)
