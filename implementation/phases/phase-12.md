# Phase 12 - Native Host Service Provisioning

## Objective

Opt-in real host install/start/stop for non-PHP core services in native mode.

## Status

- `done` (started: 2026-07-25, completed: 2026-07-25)

## Scope Checklist

- [x] `PLUME_NATIVE_HOST_PROVISION` env contract
- [x] web/nginx/apache2, mariadb, mysql, redis brew/apt/dnf drivers
- [x] Default simulate (state) behavior preserved

## Test Checklist

- [x] `tests/phase12_native_host_provision_smoke.sh` (mock pkg manager)

## Documentation Checklist

- [x] `docs/commands/services.md`
- [x] `.env.example`
- [x] Decision log D-086

## Gate Checklist (Mandatory)

- [x] Feature scope complete
- [x] Tests pass
- [x] Decision log updated
- [x] Next-phase risks written
