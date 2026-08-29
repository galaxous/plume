# Phase 19 — Native service contract (Laradock-container UX)

## Objective

Kritik native servisler Laradock container’i gibi: enable → up → live health → credentials/url. `@core` sade, status yalan soylemez, `services use` DB XOR.

## Status

- `done` (2026-08-12)
- Tracker: [phase-tracker.md](../phase-tracker.md)
- ADR: D-144

## MVP Scope

- [x] Sozlesme: [native-service-contract.md](../../docs/operations/native-service-contract.md)
- [x] `@core` queue uyeleri cikarildi; postgres/pgadmin/mailpit eklendi
- [x] Status: brew/HTTP live probe; stale PID → stopped
- [x] `services use mariadb|mysql|postgres`
- [x] Redis + mailpit credentials/url (SMTP 1025)
- [x] Smoke: `phase19_native_service_contract_smoke.sh`

## Gate Checklist

- [x] MVP scope complete
- [x] Targeted smoke yesil
- [x] Decision log D-144
- [x] Tracker satiri

## Referans

- [docs/commands/services-use.md](../../docs/commands/services-use.md)
- [lib/commands/services.sh](../../lib/commands/services.sh)
