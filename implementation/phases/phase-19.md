# Phase 19 — Native service contract (Laradock-container UX)

## Objective

Critical native services behave like Laradock containers: enable → up → live health → credentials/url. `@core` stays lean, status does not lie, `services use` enforces DB XOR.

## Status

- `done` (2026-08-12)
- Tracker: [phase-tracker.md](../phase-tracker.md)
- ADR: D-144

## MVP Scope

- [x] Contract: [native-service-contract.md](../../docs/operations/native-service-contract.md)
- [x] `@core` queue members removed; postgres/pgadmin/mailpit added
- [x] Status: brew/HTTP live probe; stale PID → stopped
- [x] `services use mariadb|mysql|postgres`
- [x] Redis + mailpit credentials/url (SMTP 1025)
- [x] Smoke: `phase19_native_service_contract_smoke.sh`

## Gate Checklist

- [x] MVP scope complete
- [x] Targeted smoke green
- [x] Decision log D-144
- [x] Tracker row

## Reference

- [docs/commands/services-use.md](../../docs/commands/services-use.md)
- [lib/commands/services.sh](../../lib/commands/services.sh)
