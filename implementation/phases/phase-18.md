# Phase 18 — Native pgAdmin (PostgreSQL UI)

## Objective

Laradock `pgadmin` parity: web UI for PostgreSQL management in native mode (`services install|up|url|credentials pgadmin`).

## Status

- `done` (2026-08-07)
- Tracker: [phase-tracker.md](../phase-tracker.md)
- ADR: D-138

## MVP Scope

- [x] Registry service: `pgadmin` (`PLUME_PGADMIN_ENABLED`, Laradock alias `PGADMIN_*`)
- [x] Driver: state venv + `pip install pgadmin4`; mock install for hermetic smoke
- [x] Dependency: `postgres` enabled
- [x] Included in `@db` group (postgres → pgadmin order)
- [x] CLI: `services url|credentials|restart pgadmin`
- [x] Docs: `docs/commands/services-pgadmin.md` + OS matrix + manifest
- [x] Smoke: `phase18_native_pgadmin_smoke.sh`

## Gate Checklist

- [x] MVP scope complete
- [x] Targeted smoke green (`phase18_native_pgadmin_smoke.sh`)
- [x] Decision log D-138
- [x] Tracker row

## Reference

- [lib/services/native_pgadmin.sh](../../lib/services/native_pgadmin.sh)
- [docs/commands/services-pgadmin.md](../../docs/commands/services-pgadmin.md)
- Laradock: `pgadmin` service (`PGADMIN_PORT=5050`)
